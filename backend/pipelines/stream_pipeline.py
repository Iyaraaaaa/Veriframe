import cv2
import numpy as np
import time
import logging
import base64
from typing import Dict, Any, List, Tuple

from detectors.face_detector import FaceDetector, FaceDetectionResult
from filters.quality_filter import QualityFilter, FaceQualityConfig
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor
from utils.image import resize_face, pad_to_square
from utils.video import decode_base64_frame

logger = logging.getLogger("veriframe.pipelines.stream")

class StreamPipeline:
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
    ):
        self.interpreter = interpreter
        self.input_details = input_details
        self.output_details = output_details
        self.face_detector = face_detector
        self.quality_filter = quality_filter
        self.temporal_filter = temporal_filter
        self.calibrator = calibrator
        self.preprocessor = preprocessor

    def create_session(self, stream_url: str) -> Dict[str, Any]:
        return {
            "scores": [],
            "boxes": [],
            "quality_scores": [],
            "detectors": [],
            "last_frame_time": time.time(),
            "created_at": time.time(),
            "stream_url": stream_url,
            "frame_count": 0,
            "faces_detected": 0,
        }

    def process_frame(self, session: Dict[str, Any], frame_base64: str) -> Dict[str, Any]:
        session["last_frame_time"] = time.time()
        session["frame_count"] += 1

        frame = decode_base64_frame(frame_base64)
        if frame is None:
            logger.warning("[StreamPipeline] Failed to decode frame")
            return self._build_response(session)

        detections = self.face_detector.detect(frame)
        if not detections:
            logger.debug("[StreamPipeline] No face detected in stream frame")
            return self._build_response(session)

        best_det = max(detections, key=lambda d: d.quality_score)
        is_good, details = self.quality_filter.is_quality_face(best_det.face_crop, frame.shape)
        if not is_good:
            logger.debug("[StreamPipeline] Low quality face skipped")
            return self._build_response(session)

        try:
            processed = self.preprocessor.preprocess_for_tflite(best_det.face_crop)
        except Exception:
            resized = cv2.resize(best_det.face_crop, (224, 224))
            processed = resized.astype(np.float32)
            processed = np.expand_dims(processed, axis=0)

        self.interpreter.set_tensor(self.input_details[0]["index"], processed)
        self.interpreter.invoke()
        output = self.interpreter.get_tensor(self.output_details[0]["index"])
        raw_score = float(output[0][0])

        calibrated_score = self.calibrator.calibrate(raw_score)
        smoothed = self.temporal_filter.update(calibrated_score)

        session["scores"].append(smoothed)
        session["boxes"].append(best_det.box)
        session["quality_scores"].append(best_det.quality_score)
        session["detectors"].append(best_det.detector)
        session["faces_detected"] += 1

        return self._build_response(session)

    def _build_response(self, session: Dict[str, Any]) -> Dict[str, Any]:
        if not session["scores"]:
            return {
                "session_confidence_score": 0.0,
                "verdict": "UNCERTAIN",
                "model_used": "EfficientViT Ensemble (Cloud Stream)",
                "frames_processed": session["frame_count"],
                "faces_detected": session["faces_detected"],
            }

        rolling = list(session["scores"])[-30:]
        avg_score = float(np.mean(rolling))
        verdict = self._adaptive_verdict(avg_score)

        return {
            "session_confidence_score": round((1.0 - avg_score) * 100.0, 2),
            "verdict": verdict,
            "model_used": "EfficientViT Ensemble (Cloud Stream)",
            "frames_processed": session["frame_count"],
            "faces_detected": session["faces_detected"],
            "rolling_window": len(rolling),
        }

    def _adaptive_verdict(self, score: float) -> str:
        if score >= 0.8:
            return "MANIPULATED"
        elif score >= 0.6:
            return "LIKELY_MANIPULATED"
        elif score >= 0.4:
            return "UNCERTAIN"
        elif score >= 0.2:
            return "LIKELY_AUTHENTIC"
        else:
            return "AUTHENTIC"