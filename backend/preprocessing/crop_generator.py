import cv2
import numpy as np
import logging
from typing import Dict, List, Tuple

logger = logging.getLogger("veriframe.preprocessing.crop_generator")

class FaceMultiCrop:
    def __init__(
        self,
        full_face: np.ndarray,
        eyes_crop: np.ndarray,
        mouth_crop: np.ndarray,
        extended_face: np.ndarray,
    ):
        self.full_face = full_face
        self.eyes_crop = eyes_crop
        self.mouth_crop = mouth_crop
        self.extended_face = extended_face

    def to_list(self) -> List[Tuple[str, np.ndarray]]:
        return [
            ("full_face", self.full_face),
            ("eyes", self.eyes_crop),
            ("mouth", self.mouth_crop),
            ("extended", self.extended_face),
        ]

class MultiCropGenerator:
    """Stage 8 — Multi-Crop Analysis Generator Engine"""

    @staticmethod
    def generate_crops(frame: np.ndarray, box: Tuple[int, int, int, int]) -> FaceMultiCrop:
        """
        Generates 4 distinct forensic region crops from a detected face:
        1. Full Face Crop
        2. Eyes Region (Upper 35-65% height slice)
        3. Mouth Region (Lower 60-95% height slice)
        4. Extended Face Region (+25% margin around bounding box)
        """
        fh, fw = frame.shape[:2]
        x, y, w, h = box

        # 1. Full Face Crop
        x1, y1 = max(0, x), max(0, y)
        x2, y2 = min(fw, x + w), min(fh, y + h)
        full_face = frame[y1:y2, x1:x2]

        if full_face.size == 0:
            full_face = np.zeros((112, 112, 3), dtype=np.uint8)

        # 2. Eyes Region Crop (y: 20% to 55% of face height)
        ey1 = max(0, y + int(h * 0.20))
        ey2 = min(fh, y + int(h * 0.55))
        ex1 = max(0, x + int(w * 0.10))
        ex2 = min(fw, x + int(w * 0.90))
        eyes_crop = frame[ey1:ey2, ex1:ex2]
        if eyes_crop.size == 0:
            eyes_crop = full_face

        # 3. Mouth Region Crop (y: 60% to 95% of face height)
        my1 = max(0, y + int(h * 0.60))
        my2 = min(fh, y + int(h * 0.95))
        mx1 = max(0, x + int(w * 0.15))
        mx2 = min(fw, x + int(w * 0.85))
        mouth_crop = frame[my1:my2, mx1:mx2]
        if mouth_crop.size == 0:
            mouth_crop = full_face

        # 4. Extended Face Region Crop (+25% margin for boundary & hair artifacts)
        margin_w = int(w * 0.25)
        margin_h = int(h * 0.25)
        ext_x1 = max(0, x - margin_w)
        ext_y1 = max(0, y - margin_h)
        ext_x2 = min(fw, x + w + margin_w)
        ext_y2 = min(fh, y + h + margin_h)
        extended_face = frame[ext_y1:ext_y2, ext_x1:ext_x2]
        if extended_face.size == 0:
            extended_face = full_face

        return FaceMultiCrop(
            full_face=full_face,
            eyes_crop=eyes_crop,
            mouth_crop=mouth_crop,
            extended_face=extended_face
        )
