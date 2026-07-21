import cv2
import numpy as np
from typing import Tuple

def resize_face(face_crop: np.ndarray, target_size: Tuple[int, int] = (224, 224)) -> np.ndarray:
    h, w = face_crop.shape[:2]
    if h == 0 or w == 0:
        raise ValueError("Invalid face crop dimensions")
    return cv2.resize(face_crop, target_size)

def compute_blur_variance(gray: np.ndarray) -> float:
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())

def compute_brightness(gray: np.ndarray) -> float:
    return float(np.mean(gray))

def compute_face_quality_score(
    face_crop: np.ndarray,
    blur_threshold: float = 100.0,
    brightness_min: float = 30.0,
    brightness_max: float = 220.0,
) -> Tuple[float, dict]:
    gray = cv2.cvtColor(face_crop, cv2.COLOR_BGR2GRAY) if len(face_crop.shape) == 3 else face_crop
    blur_var = compute_blur_variance(gray)
    brightness = compute_brightness(gray)
    h, w = face_crop.shape[:2]
    size_ratio = min(h, w) / max(face_crop.shape[0], face_crop.shape[1]) if max(face_crop.shape[:2]) > 0 else 0

    blur_score = min(1.0, blur_var / max(blur_threshold, 1.0))
    brightness_score = 1.0 - (abs(brightness - 128.0) / 128.0)
    size_score = min(1.0, size_ratio * 5.0)

    quality_score = (blur_score * 0.4 + brightness_score * 0.3 + size_score * 0.3)
    details = {
        "blur_variance": blur_var,
        "brightness": brightness,
        "size_ratio": size_ratio,
        "quality_score": quality_score,
    }
    return quality_score, details

def pad_to_square(face_crop: np.ndarray) -> np.ndarray:
    h, w = face_crop.shape[:2]
    if h == w:
        return face_crop
    size = max(h, w)
    result = np.zeros((size, size, face_crop.shape[2]) if len(face_crop.shape) == 3 else (size, size), dtype=face_crop.dtype)
    y_offset = (size - h) // 2
    x_offset = (size - w) // 2
    result[y_offset:y_offset+h, x_offset:x_offset+w] = face_crop
    return result
