import os
import cv2
import numpy as np
import time
import logging
import hashlib
import tempfile
import requests
import base64
from typing import Dict, Any, Optional, List

from config import config as app_config
from detectors.face_detector import FaceDetector
from filters.scene_forensics import SceneForensicsAnalyzer
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor
from services.reality_defender_service import RealityDefenderService
from utils.image import resize_face, pad_to_square
from utils.transparency import THRESHOLDS_IMAGE_AUDIO

logger = logging.getLogger("veriframe.pipelines.image")

class ImagePipeline:
    """
    Image Verification Pipeline.
    Supports dual-engine hybrid forensic verification:
    1. Local Biometric Face Deepfake Detection (MTCNN/MediaPipe + TFLite inference)
    2. Local Full-Scene Frequency & Sensor Noise Forensics (2D FFT frequency power spectrum + PRNU sensor noise + ELA)
    3. Reality Defender Enterprise Cloud AI (Diffusion artifacts, face swap, generative image models)
    """

    def __init__(
        self,
        interpreter,
        input_details,
        output_details,
        face_detector: FaceDetector,
        calibrator: ConfidenceCalibrator,
        preprocessor: FramePreprocessor,
        scene_analyzer: Optional[SceneForensicsAnalyzer] = None,
        rd_service: Optional[RealityDefenderService] = None,
        model_used: str = "image",
    ):
        self.interpreter = interpreter
        self.input_details = input_details
        self.output_details = output_details
        self.face_detector = face_detector
        self.calibrator = calibrator
        self.preprocessor = preprocessor
        self.scene_analyzer = scene_analyzer or SceneForensicsAnalyzer()
        self.rd_service = rd_service or RealityDefenderService()
        self.model_used = model_used

    def _compute_ela(self, image_path: str, quality: int = 90) -> float:
        """Error Level Analysis to detect resaved / spliced areas."""
        try:
            original = cv2.imread(image_path)
            if original is None:
                return 0.0
            with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
                tmp_path = tmp.name
            try:
                cv2.imwrite(tmp_path, original, [cv2.IMWRITE_JPEG_QUALITY, quality])
                resaved = cv2.imread(tmp_path)
                diff = cv2.absdiff(original, resaved)
                diff_gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
                ela_score = float(np.mean(diff_gray))
                return round(ela_score, 2)
            finally:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
        except Exception:
            return 0.0

    def process(self, image_path: str, source: str = "Local Image") -> Dict[str, Any]:
        start_time = time.time()
        logger.info(f"[ImagePipeline] Starting image verification: {image_path}")

        if not os.path.exists(image_path):
            raise ValueError(f"Image file does not exist: {image_path}")

        with open(image_path, "rb") as f:
            file_bytes = f.read()
        image_hash = hashlib.sha256(file_bytes).hexdigest()

        img = cv2.imread(image_path)
        if img is None:
            raise ValueError("Failed to decode image file with OpenCV.")

        h, w, c = img.shape
        detected_evidence: List[str] = []
        forensic_observations: List[str] = [
            f"Image dimensions: {w}x{h} ({c} color channels).",
            f"File format: {os.path.splitext(image_path)[1].upper()} ({round(len(file_bytes)/1024, 1)} KB).",
        ]

        # 1. Local Face Biometrics
        detections = self.face_detector.detect(img)
        face_fake_probs: List[float] = []
        face_detector_used = (
            detections[0].detector if detections else (
                self.face_detector.loaded_detectors[0].lower() if getattr(self.face_detector, "loaded_detectors", None) else "none"
            )
        )

        if detections:
            forensic_observations.append(f"Biometric face detection located {len(detections)} facial region(s).")
            for det in detections:
                # FaceDetectionResult.box is (x, y, w, h) and face_crop is already
                # the correctly cropped region, so use it directly rather than
                # re-deriving a slice from the box.
                face_crop = det.face_crop
                if face_crop is None or face_crop.shape[0] < 20 or face_crop.shape[1] < 20:
                    continue

                # Image model expects [1,224,224,3] float32. Use the shared
                # preprocessor (pad_to_square + resize + BGR->RGB, no /255) so the
                # image path matches the video/link/stream pipelines and the
                # isotropic-resize + pad transform the model was trained with.
                try:
                    face_tensor = self.preprocessor.preprocess_for_tflite(face_crop)
                except Exception as exc:
                    logger.debug(f"[ImagePipeline] Face preprocessing failed: {exc}")
                    continue
                self.interpreter.set_tensor(self.input_details[0]["index"], face_tensor)
                self.interpreter.invoke()
                output = self.interpreter.get_tensor(self.output_details[0]["index"])
                if output.shape[-1] == 2:
                    prob = float(output[0][1])  # index 1 = fake probability
                else:
                    prob = float(output[0][0])
                face_fake_probs.append(prob)

        # 2. Local Full-Scene Frequency Forensics
        scene_eval = self.scene_analyzer.analyze_frame(img)
        scene_fake_prob = scene_eval.get("fake_probability", 0.15)
        ela_score = self._compute_ela(image_path)
        forensic_observations.append(f"Error Level Analysis (ELA) divergence score: {ela_score}.")

        if face_fake_probs:
            local_face_prob = float(np.mean(face_fake_probs))
            local_fake_prob = 0.65 * local_face_prob + 0.35 * scene_fake_prob
            forensic_observations.append(f"Face Model ({self.model_used}) Confidence: {round(local_face_prob * 100, 1)}% fake probability.")
        else:
            # No faces: run classifier on full resized image as scene-level classifier
            try:
                # Same preprocessing as the face branch so a single model never
                # receives two different input scales ([0,255], not [0,1]).
                full_tensor = self.preprocessor.preprocess_for_tflite(img)
                self.interpreter.set_tensor(self.input_details[0]["index"], full_tensor)
                self.interpreter.invoke()
                full_out = self.interpreter.get_tensor(self.output_details[0]["index"])
                if full_out.shape[-1] == 2:
                    tflite_full_prob = float(full_out[0][1])
                else:
                    tflite_full_prob = float(full_out[0][0])
                local_fake_prob = 0.55 * tflite_full_prob + 0.45 * scene_fake_prob
                forensic_observations.append(f"Full-Scene Inference ({self.model_used}): {round(tflite_full_prob * 100, 1)}% fake probability.")
            except Exception as _e:
                local_fake_prob = scene_fake_prob
            forensic_observations.append("Non-Face Image Mode: Full-scene frequency spectrum & generative artifact analysis.")
            if scene_eval.get("evidence"):
                detected_evidence.extend(scene_eval["evidence"])

        # 3. Reality Defender Enterprise AI Detection
        rd_result = None
        degraded = False
        engines_used = ["local"]
        models_used = f"VeriFrame {self.model_used} + Scene Forensics"

        if self.rd_service and self.rd_service.detector.is_configured():
            try:
                rd_result = self.rd_service.analyze_media(image_path)
            except Exception as e:
                logger.warning(f"[ImagePipeline] Reality Defender failed: {e}")
                degraded = True
                forensic_observations.append("Reality Defender timed out or failed; local-only result.")

        if rd_result and rd_result.get("status") == "success":
            if rd_result.get("partial"):
                degraded = True
                models_used = f"VeriFrame {self.model_used} + Scene Forensics (Reality Defender partial, excluded)"
                forensic_observations.extend(rd_result.get("observations") or [])
                forensic_observations.append(
                    "Reality Defender result was PARTIAL (models still ANALYZING at the deadline) and was "
                    "excluded from the ensemble; local-only result."
                )
                detected_evidence.extend(rd_result.get("evidence") or [])
                final_fake_prob = local_fake_prob
            else:
                engines_used.append("reality_defender")
                rd_fake_prob = float(rd_result.get("fake_probability", 0.0)) / 100.0
                final_fake_prob = 0.50 * local_fake_prob + 0.50 * rd_fake_prob
                models_used = f"Ensemble: {self.model_used} + Scene Forensics + Reality Defender AI"
                if rd_result.get("evidence"):
                    detected_evidence.extend(rd_result["evidence"])
                if rd_result.get("observations"):
                    forensic_observations.extend(rd_result["observations"])
                forensic_observations.append(f"Reality Defender Cloud Deepfake Score: {rd_result.get('fake_probability')}%.")
        else:
            final_fake_prob = local_fake_prob
            if self.rd_service and self.rd_service.detector.is_configured() and rd_result is None:
                degraded = True
                if "Reality Defender timed out or failed; local-only result." not in forensic_observations:
                    forensic_observations.append("Reality Defender timed out or failed; local-only result.")

        # Calibrate & Generate Verdict
        calibrated_fake_prob = self.calibrator.calibrate(final_fake_prob)
        fake_percentage = round(calibrated_fake_prob * 100.0, 2)
        auth_percentage = round((1.0 - calibrated_fake_prob) * 100.0, 2)

        if fake_percentage > THRESHOLDS_IMAGE_AUDIO["manipulated_above_pct"]:
            legacy_verdict = "MANIPULATED"
            fine_verdict = "FAKE" if fake_percentage >= THRESHOLDS_IMAGE_AUDIO["fake_confirmed_at_or_above_pct"] else "LIKELY_FAKE"
            risk_level = "HIGH"
            if not detected_evidence:
                detected_evidence.append("AI synthesis / diffusion artifacts identified in image texture.")
        elif fake_percentage < THRESHOLDS_IMAGE_AUDIO["authentic_below_pct"]:
            legacy_verdict = "AUTHENTIC"
            fine_verdict = "REAL" if fake_percentage <= THRESHOLDS_IMAGE_AUDIO["real_confirmed_at_or_below_pct"] else "LIKELY_REAL"
            risk_level = "LOW"
            if not detected_evidence:
                detected_evidence.append(f"Optical sensor profile & natural pixel noise verified (Authenticity: {auth_percentage}%).")
        else:
            legacy_verdict = "INCONCLUSIVE"
            fine_verdict = "UNCERTAIN"
            risk_level = "MEDIUM"
            if not detected_evidence:
                detected_evidence.append("Borderline visual evidence; deepfake score is in uncertain zone.")

        confidence_val = round(abs(calibrated_fake_prob - 0.5) * 200.0, 2)

        # If Image.tflite failed to load and the video model is used, lower confidence
        if self.model_used == "video-model fallback":
            confidence_val = round(confidence_val * 0.70, 2)
            degraded = True
            forensic_observations.append("Image.tflite unavailable; used video-model fallback with lowered confidence.")

        confidence_label = "High" if confidence_val >= 75.0 else ("Medium" if confidence_val >= 50.0 else "Low")
        processing_time = round(time.time() - start_time, 2)

        # Extract thumbnail for report preview (resize image to max 320px)
        thumbnail_base64 = self._extract_image_thumbnail(image_path)

        return {
            "verificationId": f"VRF-IMG-{int(time.time() * 1000)}",
            "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "mediaType": "image/jpeg" if image_path.lower().endswith((".jpg", ".jpeg")) else "image/png",
            "source": source,
            "authenticityScore": auth_percentage,
            "fakeProbability": fake_percentage,
            "confidence": confidence_val,
            "verdict": legacy_verdict,
            "fineVerdict": fine_verdict,
            "riskLevel": risk_level,
            "modelsUsed": models_used,
            "model_used": self.model_used,
            "face_detector_used": face_detector_used,
            "engines_used": engines_used,
            "degraded": degraded,
            "detectedEvidence": detected_evidence,
            "forensicObservations": forensic_observations,
            "reportHash": image_hash,
            "facesDetected": len(detections),
            "processingTimeSec": processing_time,
            # Components kept separate (pre-calibration) so callers can re-fit
            # fusion weights or report local-only / RD-only numbers.
            "fused_fake_probability": round(float(final_fake_prob), 6),
            "local_fake_probability": round(float(local_fake_prob), 6),
            "rd_fake_probability": (
                round(float(rd_result.get("fake_probability", 0.0)) / 100.0, 6)
                if rd_result and not rd_result.get("partial") else None
            ),
            "rd_status": (
                "partial" if rd_result and rd_result.get("partial")
                else ("ok" if rd_result and rd_result.get("status") == "success"
                else ("error" if rd_result else "not_run"))
            ),
            "scene_forensics": scene_eval,
            "elaScore": ela_score,
            "heatmaps": rd_result.get("heatmaps", {}) if rd_result else {},
            "reality_defender": rd_result,
            "confidence_label": confidence_label,
            "thumbnailBase64": thumbnail_base64,
        }


    def _extract_image_thumbnail(self, image_path: str, max_size: int = 320) -> Optional[str]:
        """Extract and resize image as base64 JPEG thumbnail."""
        try:
            img = cv2.imread(image_path)
            if img is None:
                return None
            h, w = img.shape[:2]
            if max(h, w) > max_size:
                scale = max_size / max(h, w)
                new_w = int(w * scale)
                new_h = int(h * scale)
                img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
            _, buffer = cv2.imencode('.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, 80])
            return base64.b64encode(buffer).decode('utf-8')
        except Exception:
            return None
