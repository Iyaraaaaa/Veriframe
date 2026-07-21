import cv2
import numpy as np
import time
import logging
import threading
from typing import Dict, Any, Optional, Callable
from dataclasses import dataclass
from queue import Queue

from detectors.face_detector import FaceDetector, FaceDetectionResult
from filters.quality_filter import QualityFilter, FaceQualityConfig
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor
from utils.video import decode_base64_frame

logger = logging.getLogger("veriframe.workers")

@dataclass
class StreamWorkerConfig:
    frame_interval_ms: int = 400
    max_queue_size: int = 10
    auto_stop_timeout_sec: int = 300
    detector_confidence: float = 0.5

class StreamWorker:
    def __init__(
        self,
        session_id: str,
        interpreter,
        input_details,
        output_details,
        face_detector: FaceDetector,
        quality_filter: QualityFilter,
        temporal_filter: TemporalFilter,
        calibrator: ConfidenceCalibrator,
        preprocessor: FramePreprocessor,
        config: Optional[StreamWorkerConfig] = None,
        on_result: Optional[Callable[[Dict[str, Any]], None]] = None,
        on_error: Optional[Callable[[str], None]] = None,
    ):
        self.session_id = session_id
        self.interpreter = interpreter
        self.input_details = input_details
        self.output_details = output_details
        self.face_detector = face_detector
        self.quality_filter = quality_filter
        self.temporal_filter = temporal_filter
        self.calibrator = calibrator
        self.preprocessor = preprocessor
        self.config = config or StreamWorkerConfig()
        self.on_result = on_result
        self.on_error = on_error

        self.session: Dict[str, Any] = {
            "scores": [],
            "boxes": [],
            "quality_scores": [],
            "detectors": [],
            "last_frame_time": time.time(),
            "created_at": time.time(),
            "stream_url": "",
            "frame_count": 0,
            "faces_detected": 0,
        }

        self._queue: Queue = Queue(maxsize=self.config.max_queue_size)
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._cap: Optional[cv2.VideoCapture] = None

    def start_rtsp(self, rtsp_url: str) -> bool:
        try:
            self._cap = cv2.VideoCapture(rtsp_url)
            if not self._cap.isOpened():
                logger.error(f"[StreamWorker] Failed to open RTSP stream: {rtsp_url}")
                return False
            self.session["stream_url"] = rtsp_url
            self._running = True
            self._thread = threading.Thread(target=self._capture_loop, daemon=True)
            self._thread.start()
            logger.info(f"[StreamWorker] RTSP worker started for session {self.session_id}")
            return True
        except Exception as e:
            logger.error(f"[StreamWorker] RTSP start failed: {e}")
            return False

    def start_hls(self, hls_url: str) -> bool:
        return self.start_rtsp(hls_url)

    def start_rtmp(self, rtmp_url: str) -> bool:
        return self.start_rtsp(rtmp_url)

    def start_http_stream(self, http_url: str) -> bool:
        return self.start_rtsp(http_url)

    def stop(self):
        self._running = False
        if self._cap is not None:
            try:
                self._cap.release()
            except Exception:
                pass
            self._cap = None
        if self._thread is not None:
            self._thread.join(timeout=2.0)
            self._thread = None
        logger.info(f"[StreamWorker] Stopped session {self.session_id}")

    def get_status(self) -> Dict[str, Any]:
        if not self.session["scores"]:
            return {
                "status": "streaming",
                "session_confidence_score": 0.0,
                "verdict": "UNCERTAIN",
                "frames_processed": self.session["frame_count"],
                "faces_detected": self.session["faces_detected"],
            }

        rolling = list(self.session["scores"])[-30:]
        avg_score = float(np.mean(rolling))
        verdict = self._adaptive_verdict(avg_score)

        return {
            "status": "streaming",
            "session_confidence_score": round((1.0 - avg_score) * 100.0, 2),
            "verdict": verdict,
            "frames_processed": self.session["frame_count"],
            "faces_detected": self.session["faces_detected"],
            "rolling_window": len(rolling),
        }

    def _capture_loop(self):
        frame_interval = self.config.frame_interval_ms / 1000.0
        last_capture = 0.0
        while self._running:
            if self._cap is None or not self._cap.isOpened():
                time.sleep(0.1)
                continue

            now = time.time()
            if now - last_capture < frame_interval:
                time.sleep(0.01)
                continue

            last_capture = now
            ret, frame = self._cap.read()
            if not ret or frame is None:
                logger.debug(f"[StreamWorker] Frame read failed for session {self.session_id}")
                continue

            try:
                result = self._process_frame(frame)
                if self.on_result:
                    self.on_result(result)
            except Exception as e:
                logger.debug(f"[StreamWorker] Frame process error: {e}")
                if self.on_error:
                    self.on_error(str(e))

        logger.info(f"[StreamWorker] Capture loop ended for session {self.session_id}")

    def _process_frame(self, frame: np.ndarray) -> Dict[str, Any]:
        self.session["last_frame_time"] = time.time()
        self.session["frame_count"] += 1

        detections = self.face_detector.detect(frame)
        if not detections:
            return self._build_response()

        best_det = max(detections, key=lambda d: d.quality_score)
        is_good, details = self.quality_filter.is_quality_face(best_det.face_crop, frame.shape)
        if not is_good:
            return self._build_response()

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

        self.session["scores"].append(smoothed)
        self.session["boxes"].append(best_det.box)
        self.session["quality_scores"].append(best_det.quality_score)
        self.session["detectors"].append(best_det.detector)
        self.session["faces_detected"] += 1

        return self._build_response()

    def _build_response(self) -> Dict[str, Any]:
        if not self.session["scores"]:
            return {
                "session_confidence_score": 0.0,
                "verdict": "UNCERTAIN",
                "frames_processed": self.session["frame_count"],
                "faces_detected": self.session["faces_detected"],
            }

        rolling = list(self.session["scores"])[-30:]
        avg_score = float(np.mean(rolling))
        verdict = self._adaptive_verdict(avg_score)

        return {
            "session_confidence_score": round((1.0 - avg_score) * 100.0, 2),
            "verdict": verdict,
            "frames_processed": self.session["frame_count"],
            "faces_detected": self.session["faces_detected"],
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