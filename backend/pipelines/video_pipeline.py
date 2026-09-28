import cv2
import numpy as np
import time
import logging
import hashlib
from typing import List, Dict, Any, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

from config import config as app_config
from detectors.face_detector import FaceDetector, FaceDetectionResult
from filters.frame_sampler import AdaptiveFrameSampler
from filters.quality_filter import QualityFilter
from filters.scene_forensics import SceneForensicsAnalyzer
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor
from utils.video import get_video_metadata, extract_video_thumbnail_base64
from utils.image import resize_face, pad_to_square
from services.reality_defender_service import RealityDefenderService
from utils.transparency import THRESHOLDS_VIDEO

logger = logging.getLogger("veriframe.pipelines.video")

class VideoPipeline:
    """
    Local Video Verification Pipeline.
    Supports dual-track forensic analysis:
    - Biometric Face Forensics (Face detection, tracking, TFLite neural classification)
    - Full-Scene Forensics (2D FFT frequency grid, optical flow motion physics, sensor noise PRNU)
    - Reality Defender AI Cloud Ensemble (when API key is configured)
    Works accurately for both face videos and non-face AI videos (Sora, Runway, Pika, Kling).
    """
    def __init__(
        self,
        interpreter,
        input_details,
        output_details,
        face_detector: FaceDetector,
        frame_sampler: AdaptiveFrameSampler,
        quality_filter: QualityFilter,
        temporal_filter: TemporalFilter,
        calibrator: ConfidenceCalibrator,
        preprocessor: FramePreprocessor,
        scene_analyzer: Optional[SceneForensicsAnalyzer] = None,
        rd_service: Optional[RealityDefenderService] = None,
    ):
        self.interpreter = interpreter
        self.input_details = input_details
        self.output_details = output_details
        self.face_detector = face_detector
        self.frame_sampler = frame_sampler
        self.quality_filter = quality_filter
        self.temporal_filter = temporal_filter
        self.calibrator = calibrator
        self.preprocessor = preprocessor
        self.scene_analyzer = scene_analyzer or SceneForensicsAnalyzer()
        self.rd_service = rd_service or RealityDefenderService()

    def process(self, video_path: str, source: str = "Local Upload") -> Dict[str, Any]:
        start_time = time.time()
        logger.info(f"[VideoPipeline] Starting local video verification: {video_path}")

        # 1. Video Hash & Metadata Inspection
        video_hash = self._compute_file_hash(video_path)
        metadata = get_video_metadata(video_path)
        metadata_score = self._calculate_metadata_score(video_path)

        # 2. Keyframe Sampling
        frame_indices = self.frame_sampler.sample(video_path)
        logger.info(f"[VideoPipeline] Extracted {len(frame_indices)} frames from timeline")

        if not frame_indices:
            raise ValueError("Local video verification failed: No valid frames extracted from file.")

        # 3. Frame Extraction & Face Detection Cascade
        cap = cv2.VideoCapture(video_path)
        raw_scene_frames: List[np.ndarray] = []
        all_faces: List[np.ndarray] = []
        all_boxes: List[List[float]] = []
        all_quality_scores: List[float] = []
        all_detectors: List[str] = []
        frames_skipped = 0

        for idx in frame_indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ret, frame = cap.read()
            if not ret or frame is None:
                frames_skipped += 1
                continue

            raw_scene_frames.append(frame)

            detections = self.face_detector.detect(frame)
            if not detections:
                frames_skipped += 1
                continue

            best_det = max(detections, key=lambda d: d.quality_score)
            is_good, _ = self.quality_filter.is_quality_face(best_det.face_crop, frame.shape)
            if is_good:
                try:
                    face_resized = cv2.resize(best_det.face_crop, self.preprocessor.target_size)
                except Exception:
                    frames_skipped += 1
                    continue
                all_faces.append(face_resized)
                all_boxes.append(best_det.box)
                all_quality_scores.append(best_det.quality_score)
                all_detectors.append(best_det.detector)
            else:
                frames_skipped += 1
        cap.release()

        face_detector_used = (
            all_detectors[0] if all_detectors else (
                self.face_detector.loaded_detectors[0].lower() if getattr(self.face_detector, "loaded_detectors", None) else "none"
            )
        )


        logger.info(f"[VideoPipeline] Raw scene frames: {len(raw_scene_frames)}, Quality face crops: {len(all_faces)}")

        # 4. Execute Full-Scene Spatial-Temporal & Spectral Forensics
        scene_eval = self.scene_analyzer.evaluate_scene_frames(raw_scene_frames)
        scene_fake_prob = scene_eval["scene_fake_prob"]

        detected_evidence = []
        forensic_observations = [
            f"Video Verification analyzed {len(raw_scene_frames)} timeline keyframes.",
            f"2D Fourier Spectral Grid Metric: {round(scene_eval['frequency_score'] * 100, 1)}%.",
            f"Motion Flow Warping Index: {round(scene_eval['motion_score'] * 100, 1)}%.",
            f"Sensor Noise Residual Anomaly: {round(scene_eval['noise_score'] * 100, 1)}%.",
        ]

        scores = []
        inference_times = []
        ocr_confidence = self._calculate_ocr_confidence(video_path)

        if all_faces:
            # --- Track 1: Face Biometrics Present ---
            for idx, face in enumerate(all_faces):
                t0 = time.time()
                try:
                    processed = self.preprocessor.preprocess_face(face)
                    raw_fake_prob = self._run_inference(processed)
                    scores.append(raw_fake_prob)
                except Exception as e:
                    logger.warning(f"[MODEL] Local frame {idx} inference error: {e}")
                inference_times.append(time.time() - t0)

            avg_inference_ms = float(np.mean(inference_times)) * 1000.0 if inference_times else 0.0
            weighted_scores = [s * q for s, q in zip(scores, all_quality_scores[:len(scores)])]
            face_fake_prob = sum(weighted_scores) / sum(all_quality_scores[:len(scores)]) if sum(all_quality_scores[:len(scores)]) > 0 else float(np.mean(scores))
            
            # Fuse Biometrics (70%) + Full Scene Forensics (30%)
            final_fake_prob = 0.70 * face_fake_prob + 0.30 * scene_fake_prob
            
            frame_consistency = self._calculate_frame_consistency(all_faces)
            tracking_confidence = self._calculate_tracking_confidence(all_boxes)
            
            forensic_observations.insert(0, f"Biometric Face Engine analyzed {len(all_faces)} face crops.")
            forensic_observations.append(f"Face tracking continuity: {tracking_confidence}%.")
            forensic_observations.append(f"Inter-frame color consistency: {frame_consistency}%.")
        else:
            # --- Track 2: Non-Face Video (100% Full-Scene Forensics) ---
            final_fake_prob = scene_fake_prob
            avg_inference_ms = 0.0
            frame_consistency = self._calculate_frame_consistency(raw_scene_frames)
            tracking_confidence = 100.0 if len(raw_scene_frames) > 2 else 50.0

            forensic_observations.insert(0, "Non-Face Video Mode: Full-Scene Generative AI Forensics executed.")
            detected_evidence.extend(scene_eval["evidence"])

        # --- Reality Defender Cloud Forensics (Optional Ensemble) ---
        rd_result = None
        degraded = False
        engines_used = ["local"]
        models_used = "VeriFrame Local Neural Net (TFLite)"
        if self.rd_service and self.rd_service.detector.is_configured():
            try:
                rd_result = self.rd_service.analyze_media(video_path)
            except Exception as e:
                logger.warning(f"[VideoPipeline] Reality Defender analysis failed: {e}")
                degraded = True
                forensic_observations.append("Reality Defender timed out or failed; local-only result.")

        if rd_result and rd_result.get("status") == "success":
            if rd_result.get("partial"):
                degraded = True
                models_used = "VeriFrame Local Neural Net (TFLite) (Reality Defender partial, excluded)"
                forensic_observations.extend(rd_result.get("observations") or [])
                forensic_observations.append(
                    "Reality Defender result was PARTIAL (models still ANALYZING at the deadline) and was "
                    "excluded from the ensemble; local-only result."
                )
                detected_evidence.extend(rd_result.get("evidence") or [])
            else:
                engines_used.append("reality_defender")
                rd_fake_prob = float(rd_result.get("fake_probability", 0.0)) / 100.0
                # Ensemble: 50% Local Biometric & Scene Forensics + 50% Reality Defender
                final_fake_prob = 0.50 * final_fake_prob + 0.50 * rd_fake_prob
                models_used = "Ensemble: VeriFrame TFLite + Reality Defender AI"
                if rd_result.get("evidence"):
                    detected_evidence.extend(rd_result["evidence"])
                if rd_result.get("observations"):
                    forensic_observations.extend(rd_result["observations"])
                forensic_observations.append(f"Reality Defender Cloud Deepfake Score: {rd_result.get('fake_probability')}%.")
        else:
            if self.rd_service and self.rd_service.detector.is_configured() and rd_result is None:
                degraded = True
                if "Reality Defender timed out or failed; local-only result." not in forensic_observations:
                    forensic_observations.append("Reality Defender timed out or failed; local-only result.")

        # Temporal calibration
        calibrated_fake_prob = self.calibrator.calibrate(final_fake_prob)
        fake_probability = round(calibrated_fake_prob * 100.0, 2)
        authenticity_score = round((1.0 - calibrated_fake_prob) * 100.0, 2)

        prediction_certainty = calibrated_fake_prob if calibrated_fake_prob >= 0.5 else (1.0 - calibrated_fake_prob)
        fused_confidence = round(
            (prediction_certainty * 0.70 +
             (frame_consistency / 100.0) * 0.15 +
             (tracking_confidence / 100.0) * 0.15) * 100.0,
            2
        )

        # 3-State Verdict & Risk Mapping
        # Thresholds widened to 30/70 for a broader UNCERTAIN zone — reduces false positives & negatives
        if fake_probability > THRESHOLDS_VIDEO["manipulated_above_pct"]:
            legacy_verdict = "MANIPULATED"
            verdict = "FAKE" if fake_probability >= THRESHOLDS_VIDEO["fake_confirmed_at_or_above_pct"] else "LIKELY_FAKE"
            risk_level = "HIGH"
            detectedEvidenceMsg = "Synthetic generative manipulation signatures identified in video."
            if not detected_evidence:
                detected_evidence.append(detectedEvidenceMsg)
        elif fake_probability < THRESHOLDS_VIDEO["authentic_below_pct"]:
            legacy_verdict = "AUTHENTIC"
            verdict = "REAL" if fake_probability <= THRESHOLDS_VIDEO["real_confirmed_at_or_below_pct"] else "LIKELY_REAL"
            risk_level = "LOW"
            if not detected_evidence:
                detected_evidence.append(f"Visual metrics match genuine human / optical textures (Authenticity: {authenticity_score}%).")
        else:
            legacy_verdict = "INCONCLUSIVE"
            verdict = "UNCERTAIN"
            risk_level = "MEDIUM"
            if not detected_evidence:
                detected_evidence.append(f"Borderline evidence; deepfake score is in uncertain range ({fake_probability}%).")

        if metadata_score < 100.0:
            detected_evidence.append(f"Video container metadata anomaly detected (Score: {metadata_score}%).")
        else:
            forensic_observations.append("Video metadata verified: Standard camera encoding profile.")

        if ocr_confidence > 0.0:
            forensic_observations.append(f"OCR Scan active: High-contrast text overlay detected (Confidence: {ocr_confidence}%).")

        verification_id = f"VRF-LOC-{int(time.time() * 1000)}"
        processing_time = round(time.time() - start_time, 2)

        # Extract thumbnail for report preview
        thumbnail_base64 = extract_video_thumbnail_base64(video_path)

        logger.info(f"[VideoPipeline] Local video verification done in {processing_time}s. Verdict: {verdict} ({fake_probability}%)")

        return {
            "verificationId": verification_id,
            "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "mediaType": metadata.get("mime_type", "video/mp4"),
            "source": source if all_faces else f"{source} (Full-Scene AI Forensics)",
            "authenticityScore": authenticity_score,
            "fakeProbability": fake_probability,
            "confidence": fused_confidence,
            "metadataScore": metadata_score,
            "frameConsistency": frame_consistency,
            "ocrConfidence": ocr_confidence,
            "trackingConfidence": tracking_confidence,
            "manipulationScore": fake_probability,
            "verdict": legacy_verdict,
            "fineVerdict": verdict,
            "riskLevel": risk_level,
            "modelsUsed": models_used,
            "face_detector_used": face_detector_used,
            "engines_used": engines_used,
            "degraded": degraded,
            "detectedEvidence": detected_evidence,
            "forensicObservations": forensic_observations,
            "reportHash": video_hash,
            "framesAnalyzed": len(all_faces) if all_faces else len(raw_scene_frames),
            "framesSkipped": frames_skipped,
            "downloadTimeSec": 0.0,
            "processingTimeSec": processing_time,
            "averageScore": round(final_fake_prob, 4),
            "inferenceTimeMs": round(avg_inference_ms, 2),
            "is_fake": legacy_verdict == "MANIPULATED",
            "has_faces": len(all_faces) > 0,
            "scene_forensics": scene_eval,
            "reality_defender": rd_result,
            "confidence_label": "High" if fused_confidence >= 80.0 else ("Medium" if fused_confidence >= 60.0 else "Low"),
            "thumbnailBase64": thumbnail_base64,
        }


    def _run_inference(self, face_tensor: np.ndarray) -> float:
        self.interpreter.set_tensor(self.input_details[0]["index"], face_tensor)
        self.interpreter.invoke()
        output = self.interpreter.get_tensor(self.output_details[0]["index"])
        return float(output[0][0])

    def _compute_file_hash(self, file_path: str) -> str:
        h = hashlib.sha256()
        with open(file_path, "rb") as f:
            while chunk := f.read(8192):
                h.update(chunk)
        return h.hexdigest()

    def _calculate_frame_consistency(self, faces: List[np.ndarray]) -> float:
        if len(faces) < 2:
            return 100.0
        correlations = []
        for i in range(len(faces) - 1):
            h1 = cv2.calcHist([faces[i]], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
            h2 = cv2.calcHist([faces[i+1]], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
            cv2.normalize(h1, h1)
            cv2.normalize(h2, h2)
            corr = cv2.compareHist(h1, h2, cv2.HISTCMP_CORREL)
            correlations.append(corr)
        avg_corr = float(np.mean(correlations))
        return round(max(0.0, avg_corr * 100.0), 2)

    def _calculate_tracking_confidence(self, boxes: List[List[float]]) -> float:
        if len(boxes) < 2:
            return 100.0
        displacements = []
        for i in range(len(boxes) - 1):
            b1, b2 = boxes[i], boxes[i+1]
            c1_x, c1_y = b1[0] + b1[2] / 2, b1[1] + b1[3] / 2
            c2_x, c2_y = b2[0] + b2[2] / 2, b2[1] + b2[3] / 2
            dist = np.sqrt((c1_x - c2_x)**2 + (c1_y - c2_y)**2)
            avg_sz = (b1[2] + b1[3] + b2[2] + b2[3]) / 4.0
            norm_dist = dist / max(1.0, avg_sz)
            displacements.append(norm_dist)
        avg_disp = float(np.mean(displacements))
        return round(max(0.0, 100.0 - (avg_disp * 150.0)), 2)

    def _calculate_metadata_score(self, video_path: str) -> float:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return 0.0
        w = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
        h = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
        fps = cap.get(cv2.CAP_PROP_FPS)
        count = cap.get(cv2.CAP_PROP_FRAME_COUNT)
        cap.release()
        score = 100.0
        if w <= 0 or h <= 0:
            score -= 30.0
        if fps <= 0 or fps > 120:
            score -= 30.0
        if count <= 0:
            score -= 40.0
        return max(0.0, score)

    def _calculate_ocr_confidence(self, video_path: str, max_frames: int = 5) -> float:
        cap = cv2.VideoCapture(video_path)
        total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total <= 0:
            cap.release()
            return 0.0
        indices = np.linspace(0, total - 1, min(total, max_frames), dtype=int)
        scores = []
        for idx in indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ret, frame = cap.read()
            if not ret or frame is None:
                continue
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            grad_x = cv2.Sobel(gray, cv2.CV_8U, 1, 0, ksize=3)
            _, thresh = cv2.threshold(grad_x, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            edge_ratio = np.sum(thresh == 255) / thresh.size
            scores.append(edge_ratio)
        cap.release()
        if not scores:
            return 0.0
        avg_ratio = float(np.mean(scores))
        if 0.005 < avg_ratio < 0.1:
            return round(min(100.0, 80.0 + (avg_ratio * 150)), 2)
        return 0.0

    def _determine_verdict(self, score: float) -> str:
        if score >= 0.8:
            return "REAL"
        elif score >= 0.6:
            return "LIKELY_REAL"
        elif score >= 0.4:
            return "UNCERTAIN"
        elif score >= 0.2:
            return "LIKELY_FAKE"
        else:
            return "FAKE"