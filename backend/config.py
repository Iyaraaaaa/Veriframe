import os
from dataclasses import dataclass, field
from typing import Optional, List

@dataclass
class Config:
    INPUT_SIZE: tuple = (224, 224)
    MAX_FRAMES: int = 40
    TARGET_FRAMES: int = 100
    MIN_FACE_SIZE: int = 20
    BLUR_VAR_THRESHOLD: float = 15.0
    BRIGHTNESS_MIN: float = 10.0
    BRIGHTNESS_MAX: float = 245.0
    FACE_SIZE_RATIO_MIN: float = 0.02
    FACE_SIZE_RATIO_MAX: float = 0.95
    HEAD_PITCH_THRESHOLD: float = 30.0
    HEAD_YAW_THRESHOLD: float = 30.0
    TEMPORAL_WINDOW_SIZE: int = 15
    STREAM_WINDOW_SIZE: int = 30
    STREAM_INFERENCE_INTERVAL_MS: int = 400
    CONFIDENCE_CALIBRATION_TEMP: float = 1.0
    DUPLICATE_FRAME_THRESHOLD: float = 0.92
    SCENE_CHANGE_THRESHOLD: float = 0.3
    MOTION_PEAK_THRESHOLD: float = 15.0
    MODEL_FALLBACK_PATHS: list = None
    ENABLE_RETINAFACE: bool = True
    ENABLE_SCRFD: bool = True
    ENABLE_MEDIAPIPE: bool = True
    ENABLE_MTCNN: bool = True
    CACHE_DIR: str = ""
    CACHE_ENABLED: bool = True
    MAX_VIDEO_SIZE_MB: int = 500
    URL_DOWNLOAD_TIMEOUT: int = 120
    FRAME_EXTRACTION_WORKERS: int = 4
    INFERENCE_BATCH_SIZE: int = 8
    USE_GPU_DELEGATE: bool = False

    def __post_init__(self):
        if self.MODEL_FALLBACK_PATHS is None:
            self.MODEL_FALLBACK_PATHS = [
                os.path.join(os.path.dirname(__file__), "..", "assets", "veriframe_model.tflite"),
                os.path.join(os.path.dirname(__file__), "veriframe_model.tflite"),
                os.path.join(os.path.dirname(__file__), "assets", "veriframe_model.tflite"),
                os.path.join(os.getcwd(), "veriframe_model.tflite"),
                os.path.join(os.getcwd(), "assets", "veriframe_model.tflite"),
                os.path.join(os.path.dirname(__file__), "..", "Veriframe", "assets", "veriframe_model.tflite"),
            ]
        if not self.CACHE_DIR:
            parent_cache = os.path.join(os.path.dirname(__file__), "..", "cache")
            local_cache = os.path.join(os.path.dirname(__file__), "cache")
            if os.path.exists(parent_cache):
                self.CACHE_DIR = parent_cache
            else:
                self.CACHE_DIR = local_cache
        os.makedirs(self.CACHE_DIR, exist_ok=True)

config = Config()
