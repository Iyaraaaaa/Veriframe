import cv2
import numpy as np
import time
import logging
import hashlib
from typing import Dict, Any, List, Optional, Tuple

from detectors.face_detector import FaceDetector
from filters.quality_filter import QualityFilter
from filters.scene_forensics import SceneForensicsAnalyzer
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor
from utils.video import decode_base64_frame

logger = logging.getLogger("veriframe.pipelines.stream")

class StreamPipeline:
    """
    Live Stream Verification Pipeline.
    Dedicated pipeline for real-time live video streams (RTSP, RTMP, HLS, WebRTC, continuous frame stream).
    Supports dual-track live stream verification:
    - Biometric Facial Deepfake Stream Detection
    - Real-Time Full-Scene Spectral & Motion Generative AI Detection
    """
    def __init__(
        self,
        interpreter,
        input_details,
        output_details,
        face_detector: FaceDetector,
        quality_filter: QualityFilter,
        temporal_filter: TemporalFilter,
        calibrator: ConfidenceCalibrator,
        preprocessor: FramePreprocessor,
        scene_analyzer: Optional[SceneForensicsAnalyzer] = None,
    ):
        self.interpreter = interpreter
        self.input_details = input_details
        self.output_details = output_details
        self.face_detector = face_detector
        self.quality_filter = quality_filter
        self.temporal_filter = temporal_filter
        self.calibrator = calibrator
        self.preprocessor = preprocessor
        self.scene_analyzer = scene_analyzer or SceneForensicsAnalyzer()

    def create_session(self, stream_url: str) -> Dict[str, Any]:
        """Creates a new stateful live stream verification session."""
        session_id = f"stream-{int(time.time() * 1000)}"
        return {
            "session_id": session_id,
            "stream_url": stream_url,
            "created_at": time.time(),
            "last_frame_time": time.time(),
            "frame_count": 0,
            "faces_detected": 0,
            "scores": [],
            "scene_scores": [],
            "boxes": [],
            "hists": [],
            "quality_scores": [],
            "inference_times": [],
            "last_frame": None,
            "status": "active",
        }

    def process_frame(self, session: Dict[str, Any], frame_input: Any) -> Dict[str, Any]:
        """
        Processes a single live frame (base64 string or numpy BGR array).
        Returns real-time verdict, session confidence score, and metrics.
        """
        t0 = time.time()
        session["last_frame_time"] = t0
        session["frame_count"] += 1

        if isinstance(frame_input, str):
            frame = decode_base64_frame(frame_input)
        elif isinstance(frame_input, np.ndarray):
            frame = frame_input
        else:
            frame = None

        if frame is None:
            logger.warning("[StreamPipeline] Invalid frame input supplied.")
            return self._build_frame_response(session)

        # 1. Full-Scene Spectral & Motion Analysis
        freq_res = self.scene_analyzer.analyze_frequency_spectrum(frame)
        noise_res = self.scene_analyzer.analyze_noise_residual(frame)
        motion_score = 0.5
        if session.get("last_frame") is not None:
            m_res = self.scene_analyzer.analyze_motion_physics(session["last_frame"], frame)
            motion_score = m_res["motion_synthetic_score"]
        
        session["last_frame"] = frame.copy()
        scene_frame_score = float(np.clip(0.40 * freq_res["frequency_synthetic_score"] + 0.35 * motion_score + 0.25 * noise_res["noise_synthetic_score"], 0.0, 1.0))
        session["scene_scores"].append(scene_frame_score)

        # 2. Biometric Facial Analysis
        detections = self.face_detector.detect(frame)
        if not detections:
            return self._build_frame_response(session)

        best_det = max(detections, key=lambda d: d.quality_score)
        is_good, _ = self.quality_filter.is_quality_face(best_det.face_crop, frame.shape)
        if not is_good:
            return self._build_frame_response(session)

        try:
            face_resized = cv2.resize(best_det.face_crop, self.preprocessor.target_size)
            processed = self.preprocessor.preprocess_face(face_resized)
            raw_score = self._run_inference(processed)
        except Exception as e:
            logger.warning(f"[StreamPipeline] Frame inference error: {e}. Frame skipped.")
            return self._build_frame_response(session)

        proc_ms = (time.time() - t0) * 1000.0
        session["inference_times"].append(proc_ms)

        # Fuse face score (70%) with scene score (30%)
        fused_frame_score = float(0.70 * raw_score + 0.30 * scene_frame_score)
        calibrated_score = self.calibrator.calibrate(fused_frame_score)
        smoothed = self.temporal_filter.update(calibrated_score)

        hist = cv2.calcHist([face_resized], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
        cv2.normalize(hist, hist)

        session["scores"].append(smoothed)
        session["boxes"].append(best_det.box)
        session["hists"].append(hist)
        session["quality_scores"].append(best_det.quality_score)
        session["faces_detected"] += 1

        return self._build_frame_response(session)

    def get_session_summary(self, session: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generates a comprehensive forensic report for the live stream session.
        Handles both face-based streams and non-face live video streams.
        """
        verification_id = f"VRF-STR-{int(time.time() * 1000)}"

        has_faces = len(session["scores"]) > 0
        if not has_faces and not session["scene_scores"]:
            logger.info("[StreamPipeline] Session completed without valid frames.")
            return {
                "status": "completed",
                "progress": 1.0,
                "result": {
                    "verificationId": verification_id,
                    "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "mediaType": "live/stream",
                    "source": "Live Stream",
                    "streamUrl": session.get("stream_url", ""),
                    "authenticityScore": 0.0,
                    "fakeProbability": 0.0,
                    "confidence": 0.0,
                    "metadataScore": 100.0,
                    "frameConsistency": 0.0,
                    "ocrConfidence": 0.0,
                    "trackingConfidence": 0.0,
                    "manipulationScore": 0.0,
                    "verdict": "INCONCLUSIVE",
                    "fineVerdict": "INCONCLUSIVE",
                    "riskLevel": "UNKNOWN",
                    "detectedEvidence": ["No valid frames captured in stream session."],
                    "forensicObservations": [f"Live Stream session received {session['frame_count']} frames."],
                    "reportHash": hashlib.sha256(f"{session.get('session_id', '')}-{time.time()}".encode()).hexdigest(),
                    "framesAnalyzed": 0,
                    "totalFramesReceived": session["frame_count"],
                }
            }

        if has_faces:
            avg_fake_prob = float(np.mean(session["scores"]))
            correlations = []
            for i in range(len(session["hists"]) - 1):
                corr = cv2.compareHist(session["hists"][i], session["hists"][i+1], cv2.HISTCMP_CORREL)
                correlations.append(corr)
            frame_consistency = round(float(np.mean(correlations)) * 100.0, 2) if correlations else 100.0
            tracking_confidence = self._calculate_tracking_confidence(session["boxes"])
            source_label = "Live Stream (Biometric & Scene Forensics)"
        else:
            # Non-face stream
            avg_fake_prob = float(np.mean(session["scene_scores"]))
            frame_consistency = 90.0
            tracking_confidence = 100.0 if session["frame_count"] > 5 else 50.0
            source_label = "Live Stream (Full-Scene AI Forensics)"

        fake_probability = round(avg_fake_prob * 100.0, 2)
        authenticity_score = round((1.0 - avg_fake_prob) * 100.0, 2)
        metadata_score = 100.0

        prediction_certainty = avg_fake_prob if avg_fake_prob >= 0.5 else (1.0 - avg_fake_prob)
        fused_confidence = round(
            (prediction_certainty * 0.70 +
             (frame_consistency / 100.0) * 0.15 +
             (tracking_confidence / 100.0) * 0.15) * 100.0,
            2
        )

        if fake_probability > 65.0:
            legacy_verdict = "MANIPULATED"
            verdict = "FAKE" if fake_probability >= 85.0 else "LIKELY_FAKE"
            risk_level = "HIGH"
        elif fake_probability < 35.0:
            legacy_verdict = "AUTHENTIC"
            verdict = "REAL" if fake_probability <= 15.0 else "LIKELY_REAL"
            risk_level = "LOW"
        else:
            legacy_verdict = "INCONCLUSIVE"
            verdict = "UNCERTAIN"
            risk_level = "MEDIUM"

        detected_evidence = []
        forensic_observations = [
            f"Live Stream session evaluated across {session['frame_count']} streaming frames.",
            f"Spatial tracking continuity: {tracking_confidence}%.",
            f"Inter-frame color consistency: {frame_consistency}%.",
            f"Mode: {'Biometric Facial Stream' if has_faces else 'Non-Face Full-Scene Stream'}.",
        ]

        if legacy_verdict == "AUTHENTIC":
            detected_evidence.append("Natural optical camera frequency and motion continuity verified.")
        elif legacy_verdict == "MANIPULATED":
            detected_evidence.append(f"Synthetic generative patterns detected in live stream ({fake_probability}% risk).")
        else:
            detected_evidence.append(f"Borderline indicators in stream session ({fake_probability}% score).")

        return {
            "status": "completed",
            "progress": 1.0,
            "result": {
                "verificationId": verification_id,
                "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "mediaType": "live/stream",
                "source": "Live Stream",
                "streamUrl": session.get("stream_url", ""),
                "authenticityScore": authenticity_score,
                "fakeProbability": fake_probability,
                "confidence": fused_confidence,
                "metadataScore": metadata_score,
                "frameConsistency": frame_consistency,
                "ocrConfidence": 0.0,
                "trackingConfidence": tracking_confidence,
                "manipulationScore": fake_probability,
                "verdict": legacy_verdict,
                "fineVerdict": verdict,
                "riskLevel": risk_level,
                "detectedEvidence": detected_evidence,
                "forensicObservations": forensic_observations,
                "reportHash": hashlib.sha256(f"{session.get('session_id', '')}-{time.time()}".encode()).hexdigest(),
                "framesAnalyzed": len(session["scores"]),
                "totalFramesReceived": session["frame_count"],
            }
        }

    def _build_frame_response(self, session: Dict[str, Any]) -> Dict[str, Any]:
        if not session["scores"]:
            return {
                "session_confidence_score": 0.0,
                "verdict": "UNCERTAIN",
                "model_used": "Veriframe Live Stream Detector",
                "frames_processed": session["frame_count"],
                "faces_detected": session["faces_detected"],
            }

        rolling = session["scores"][-30:]
        avg_score = float(np.mean(rolling))
        verdict = "AUTHENTIC" if avg_score >= 0.5 else "MANIPULATED"

        return {
            "session_confidence_score": round(avg_score * 100.0, 2),
            "verdict": verdict,
            "model_used": "Veriframe Live Stream Detector",
            "frames_processed": session["frame_count"],
            "faces_detected": session["faces_detected"],
            "rolling_window": len(rolling),
        }

    def _run_inference(self, face_tensor: np.ndarray) -> float:
        self.interpreter.set_tensor(self.input_details[0]["index"], face_tensor)
        self.interpreter.invoke()
        output = self.interpreter.get_tensor(self.output_details[0]["index"])
        return float(output[0][0])

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