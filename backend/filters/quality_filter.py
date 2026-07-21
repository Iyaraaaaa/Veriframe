import cv2
import numpy as np
from typing import List, Tuple, Dict, Any
from dataclasses import dataclass
from utils.image import compute_face_quality_score, compute_blur_variance, compute_brightness

@dataclass
class FaceQualityConfig:
    blur_variance_threshold: float = 100.0
    brightness_min: float = 30.0
    brightness_max: float = 220.0
    face_size_ratio_min: float = 0.05
    face_size_ratio_max: float = 0.9
    min_face_size: int = 40
    quality_score_threshold: float = 0.4
    motion_blur_threshold: float = 80.0
    max_face_ratio: float = 0.85
    side_profile_threshold: float = 0.35

class QualityFilter:
    def __init__(self, config: FaceQualityConfig = None):
        self.config = config or FaceQualityConfig()

    def is_quality_face(self, face_crop: np.ndarray, frame_shape: Tuple[int, int]) -> Tuple[bool, Dict[str, Any]]:
        h, w = face_crop.shape[:2]
        if h < self.config.min_face_size or w < self.config.min_face_size:
            return False, {"reason": "face_too_small", "size": (w, h)}

        frame_h, frame_w = frame_shape[:2]
        face_area = w * h
        frame_area = frame_w * frame_h
        size_ratio = face_area / max(frame_area, 1)

        if size_ratio < self.config.face_size_ratio_min:
            return False, {"reason": "face_ratio_too_small", "ratio": size_ratio}
        if size_ratio > self.config.max_face_ratio:
            return False, {"reason": "face_ratio_too_large", "ratio": size_ratio}

        gray = cv2.cvtColor(face_crop, cv2.COLOR_BGR2GRAY) if len(face_crop.shape) == 3 else face_crop
        blur_var = compute_blur_variance(gray)
        brightness = compute_brightness(gray)
        quality_score, details = compute_face_quality_score(face_crop)

        if blur_var < self.config.blur_variance_threshold:
            return False, {"reason": "blurry", "blur_variance": blur_var, "quality_score": quality_score, **details}

        if brightness < self.config.brightness_min:
            return False, {"reason": "too_dark", "brightness": brightness, "quality_score": quality_score, **details}
        if brightness > self.config.brightness_max:
            return False, {"reason": "too_bright", "brightness": brightness, "quality_score": quality_score, **details}

        if quality_score < self.config.quality_score_threshold:
            return False, {"reason": "low_quality", "quality_score": quality_score, **details}

        return True, {"quality_score": quality_score, "blur_variance": blur_var, "brightness": brightness, **details}

    def filter_faces(self, face_crops: List[np.ndarray], boxes: List[Tuple[int, int, int, int]], frame_shape: Tuple[int, int]) -> Tuple[List[np.ndarray], List[Tuple[int, int, int, int]], List[Dict[str, Any]]]:
        good_faces = []
        good_boxes = []
        good_details = []
        for face_crop, box in zip(face_crops, boxes):
            is_good, details = self.is_quality_face(face_crop, frame_shape)
            if is_good:
                good_faces.append(face_crop)
                good_boxes.append(box)
                good_details.append(details)
        return good_faces, good_boxes, good_details