import cv2
import numpy as np
from typing import Tuple, Optional
import logging

logger = logging.getLogger("veriframe.preprocessing")

class FramePreprocessor:
    def __init__(self, target_size: Tuple[int, int] = (224, 224)):
        self.target_size = target_size
        self.clip_limit = 2.0
        self.tile_grid_size = (8, 8)
        self.gamma = 1.2

    def apply_clahe(self, image: np.ndarray) -> np.ndarray:
        lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=self.clip_limit, tileGridSize=self.tile_grid_size)
        l = clahe.apply(l)
        lab = cv2.merge([l, a, b])
        return cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

    def gamma_correction(self, image: np.ndarray, gamma: Optional[float] = None) -> np.ndarray:
        gamma = gamma or self.gamma
        inv_gamma = 1.0 / gamma
        table = np.array([((i / 255.0) ** inv_gamma) * 255 for i in range(256)], dtype=np.uint8)
        return cv2.LUT(image, table)

    def normalize(self, image: np.ndarray) -> np.ndarray:
        if len(image.shape) == 3 and image.shape[2] == 3:
            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        return image.astype(np.float32)

    def align_face(self, face_crop: np.ndarray, landmarks: Optional[Tuple] = None) -> np.ndarray:
        if landmarks is None:
            return face_crop
        try:
            left_eye = np.mean(landmarks[0], axis=0)
            right_eye = np.mean(landmarks[1], axis=0)
            dy = right_eye[1] - left_eye[1]
            dx = right_eye[0] - left_eye[0]
            angle = np.degrees(np.arctan2(dy, dx))
            center = (face_crop.shape[1] // 2, face_crop.shape[0] // 2)
            M = cv2.getRotationMatrix2D(center, angle, 1.0)
            aligned = cv2.warpAffine(face_crop, M, (face_crop.shape[1], face_crop.shape[0]),
                                    borderMode=cv2.BORDER_REFLECT)
            return aligned
        except Exception:
            return face_crop

    def center_crop(self, image: np.ndarray, target_size: Optional[Tuple[int, int]] = None) -> np.ndarray:
        target_size = target_size or self.target_size
        h, w = image.shape[:2]
        th, tw = target_size
        if h == th and w == tw:
            return image
        aspect = w / h
        if aspect > tw / th:
            new_w = tw
            new_h = int(tw / aspect)
        else:
            new_h = th
            new_w = int(th * aspect)
        resized = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_AREA)
        top = (th - new_h) // 2
        left = (tw - new_w) // 2
        canvas = np.zeros((th, tw, image.shape[2]) if len(image.shape) == 3 else (th, tw), dtype=image.dtype)
        canvas[top:top+new_h, left:left+new_w] = resized
        return canvas

    def pad_to_square(self, face_crop: np.ndarray) -> np.ndarray:
        h, w = face_crop.shape[:2]
        if h == w:
            return face_crop
        size = max(h, w)
        result = np.zeros((size, size, face_crop.shape[2]) if len(face_crop.shape) == 3 else (size, size), dtype=face_crop.dtype)
        y_offset = (size - h) // 2
        x_offset = (size - w) // 2
        result[y_offset:y_offset+h, x_offset:x_offset+w] = face_crop
        return result

    def preprocess_face(self, face_crop: np.ndarray) -> np.ndarray:
        if face_crop is None or face_crop.size == 0:
            raise ValueError("Empty face crop")
        square = self.pad_to_square(face_crop)
        resized = cv2.resize(square, self.target_size, interpolation=cv2.INTER_AREA)
        enhanced = self.apply_clahe(resized)
        enhanced = self.gamma_correction(enhanced)
        normalized = self.normalize(enhanced)
        normalized = np.expand_dims(normalized, axis=0)
        return normalized

    def preprocess_for_tflite(self, face_crop: np.ndarray) -> np.ndarray:
        square = self.pad_to_square(face_crop)
        resized = cv2.resize(square, self.target_size, interpolation=cv2.INTER_AREA)
        resized = resized.astype(np.float32)
        normalized = self.normalize(resized)
        normalized = np.expand_dims(normalized, axis=0)
        return normalized