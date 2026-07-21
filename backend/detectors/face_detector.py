import cv2
import numpy as np
from typing import List, Tuple, Optional
import logging
import os

from config import config as app_config
from utils.image import compute_face_quality_score

logger = logging.getLogger("veriframe.detectors")

class FaceDetectionResult:
    def __init__(self, face_crop: np.ndarray, box: Tuple[int, int, int, int], quality_score: float, detector: str, landmarks: Optional[Tuple] = None):
        self.face_crop = face_crop
        self.box = box
        self.quality_score = quality_score
        self.detector = detector
        self.landmarks = landmarks

    def to_dict(self):
        return {
            "box": self.box,
            "quality_score": self.quality_score,
            "detector": self.detector,
        }

class FaceDetector:
    def __init__(self, input_size: Tuple[int, int] = (224, 224)):
        self.input_size = input_size
        self.retinaface = None
        self.scrfd = None
        self.mtcnn = None
        self.mediapipe_detector = None
        self._haar_cascade = None
        self._init_detectors()

    def _init_detectors(self):
        if app_config.ENABLE_RETINAFACE:
            try:
                from insightface.app import FaceAnalysis
                self.retinaface = FaceAnalysis(name="buffalo_l", providers=['CPU'])
                self.retinaface.prepare(ctx_id=0, det_size=(640, 640))
                logger.info("[FaceDetector] RetinaFace (insightface) initialized")
            except Exception as e:
                logger.warning(f"[FaceDetector] RetinaFace init failed: {e}")
                self.retinaface = None

        if app_config.ENABLE_SCRFD:
            try:
                from insightface.scrfd import SCRFD
                scrfd_path = os.path.join(os.path.dirname(__file__), "..", "models", "scrfd_2.5g.onnx")
                if os.path.exists(scrfd_path):
                    self.scrfd = SCRFD(scrfd_path)
                    logger.info("[FaceDetector] SCRFD initialized")
                else:
                    logger.info("[FaceDetector] SCRFD model not found, skipping")
            except Exception as e:
                logger.warning(f"[FaceDetector] SCRFD init failed: {e}")
                self.scrfd = None

        try:
            import torch
            from facenet_pytorch import MTCNN
            torch.set_grad_enabled(False)
            device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
            self.mtcnn = MTCNN(margin=0, keep_all=False, select_largest=True, device=device)
            logger.info(f"[FaceDetector] MTCNN initialized on {device}")
        except Exception as e:
            logger.warning(f"[FaceDetector] MTCNN init failed: {e}")

        try:
            import mediapipe as mp
            mp_face = mp.solutions.face_detection
            self.mediapipe_detector = mp_face.FaceDetection(model_selection=1, min_detection_confidence=0.5)
            logger.info("[FaceDetector] MediaPipe Face Detection initialized")
        except Exception as e:
            logger.warning(f"[FaceDetector] MediaPipe init failed: {e}")

    def detect(self, frame: np.ndarray) -> List[FaceDetectionResult]:
        results = []

        if self.retinaface is not None:
            try:
                results = self._detect_retinaface(frame)
                if results:
                    return results
            except Exception as e:
                logger.debug(f"[FaceDetector] RetinaFace detection error: {e}")

        if self.scrfd is not None:
            try:
                results = self._detect_scrfd(frame)
                if results:
                    return results
            except Exception as e:
                logger.debug(f"[FaceDetector] SCRFD detection error: {e}")

        if self.mtcnn is not None:
            try:
                results = self._detect_mtcnn(frame)
                if results:
                    logger.debug(f"[FaceDetector] MTCNN detected {len(results)} face(s)")
                    return results
            except Exception as e:
                logger.debug(f"[FaceDetector] MTCNN detection error: {e}")

        if self.mediapipe_detector is not None:
            try:
                results = self._detect_mediapipe(frame)
                if results:
                    logger.debug(f"[FaceDetector] MediaPipe detected {len(results)} face(s)")
                    return results
            except Exception as e:
                logger.debug(f"[FaceDetector] MediaPipe detection error: {e}")

        results = self._detect_haar(frame)
        if results:
            logger.debug(f"[FaceDetector] Haar detected {len(results)} face(s)")
        return results

    def _detect_retinaface(self, frame: np.ndarray) -> List[FaceDetectionResult]:
        faces = self.retinaface.get(frame)
        results = []
        for face in faces:
            x1, y1, x2, y2 = face.bbox.astype(int)
            w = x2 - x1
            h = y2 - y1
            if w <= 0 or h <= 0:
                continue
            p_w = 0
            p_h = 0
            if h > w:
                p_w = int((h - w) / 2)
            elif h < w:
                p_h = int((w - h) / 2)
            ymin_p = max(y1 - p_h, 0)
            ymax_p = min(y2 + p_h, frame.shape[0])
            xmin_p = max(x1 - p_w, 0)
            xmax_p = min(x2 + p_w, frame.shape[1])
            face_crop = frame[ymin_p:ymax_p, xmin_p:xmax_p]
            if face_crop.size == 0:
                continue
            quality_score = compute_face_quality_score(face_crop)[0]
            landmarks = face.kps if hasattr(face, 'kps') and face.kps is not None else None
            results.append(FaceDetectionResult(
                face_crop=face_crop,
                box=(x1, y1, w, h),
                quality_score=quality_score,
                detector="retinaface",
                landmarks=landmarks,
            ))
        return results

    def _detect_scrfd(self, frame: np.ndarray) -> List[FaceDetectionResult]:
        bboxes, kpss = self.scrfd.detect(frame)
        results = []
        if bboxes is None or len(bboxes) == 0:
            return results
        for i, bbox in enumerate(bboxes):
            x1, y1, x2, y2 = int(bbox[0]), int(bbox[1]), int(bbox[2]), int(bbox[3])
            w = x2 - x1
            h = y2 - y1
            if w <= 0 or h <= 0:
                continue
            p_w = 0
            p_h = 0
            if h > w:
                p_w = int((h - w) / 2)
            elif h < w:
                p_h = int((w - h) / 2)
            ymin_p = max(y1 - p_h, 0)
            ymax_p = min(y2 + p_h, frame.shape[0])
            xmin_p = max(x1 - p_w, 0)
            xmax_p = min(x2 + p_w, frame.shape[1])
            face_crop = frame[ymin_p:ymax_p, xmin_p:xmax_p]
            if face_crop.size == 0:
                continue
            quality_score = compute_face_quality_score(face_crop)[0]
            landmarks = kpss[i] if kpss is not None and i < len(kpss) else None
            results.append(FaceDetectionResult(
                face_crop=face_crop,
                box=(x1, y1, w, h),
                quality_score=quality_score,
                detector="scrfd",
                landmarks=landmarks,
            ))
        return results

    def _detect_mtcnn(self, frame: np.ndarray) -> List[FaceDetectionResult]:
        import torch
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        boxes, probs, landmarks = self.mtcnn.detect(frame_rgb, landmarks=True)
        results = []
        if boxes is None:
            return results
        for i, box in enumerate(boxes):
            if box is None:
                continue
            xmin, ymin, xmax, ymax = [int(b) for b in box]
            w = xmax - xmin
            h = ymax - ymin
            if w <= 0 or h <= 0:
                continue
            p_w = 0
            p_h = 0
            if h > w:
                p_w = int((h - w) / 2)
            elif h < w:
                p_h = int((w - h) / 2)
            ymin_p = max(ymin - p_h, 0)
            ymax_p = min(ymax + p_h, frame.shape[0])
            xmin_p = max(xmin - p_w, 0)
            xmax_p = min(xmax + p_w, frame.shape[1])
            face_crop = frame[ymin_p:ymax_p, xmin_p:xmax_p]
            if face_crop.size == 0:
                continue
            quality_score = compute_face_quality_score(face_crop)[0]
            lm = landmarks[i] if landmarks is not None and i < len(landmarks) else None
            results.append(FaceDetectionResult(
                face_crop=face_crop,
                box=(xmin, ymin, w, h),
                quality_score=quality_score,
                detector="mtcnn",
                landmarks=lm,
            ))
        return results

    def _detect_mediapipe(self, frame: np.ndarray) -> List[FaceDetectionResult]:
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        h, w = frame.shape[:2]
        results_raw = self.mediapipe_detector.process(frame_rgb)
        results = []
        if results_raw.detections is None:
            return results
        for detection in results_raw.detections:
            bbox = detection.location_data.relative_bounding_box
            xmin = int(bbox.xmin * w)
            ymin = int(bbox.ymin * h)
            bw = int(bbox.width * w)
            bh = int(bbox.height * h)
            xmax = min(xmin + bw, w)
            ymax = min(ymin + bh, h)
            xmin = max(xmin, 0)
            ymin = max(ymin, 0)
            face_crop = frame[ymin:ymax, xmin:xmax]
            if face_crop.size == 0:
                continue
            quality_score = compute_face_quality_score(face_crop)[0]
            results.append(FaceDetectionResult(
                face_crop=face_crop,
                box=(xmin, ymin, bw, bh),
                quality_score=quality_score,
                detector="mediapipe",
            ))
        return results

    def _detect_haar(self, frame: np.ndarray) -> List[FaceDetectionResult]:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        if self._haar_cascade is None:
            haar_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
            self._haar_cascade = cv2.CascadeClassifier(haar_path)
        detected = self._haar_cascade.detectMultiScale(gray, 1.1, 5)
        results = []
        if detected is None or len(detected) == 0:
            return results
        for (x, y, w, h) in detected:
            face_crop = frame[y:y+h, x:x+w]
            if face_crop.size == 0:
                continue
            quality_score = compute_face_quality_score(face_crop)[0]
            results.append(FaceDetectionResult(
                face_crop=face_crop,
                box=(x, y, w, h),
                quality_score=quality_score,
                detector="haar",
            ))
        return results

    def close(self):
        if self.retinaface is not None:
            try:
                del self.retinaface
                self.retinaface = None
            except Exception:
                pass
        if self.scrfd is not None:
            try:
                del self.scrfd
                self.scrfd = None
            except Exception:
                pass
        if self.mtcnn is not None:
            try:
                self.mtcnn = None
            except Exception:
                pass
        if self.mediapipe_detector is not None:
            try:
                self.mediapipe_detector.close()
            except Exception:
                pass