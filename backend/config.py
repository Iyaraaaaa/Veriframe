import os
import logging
from dataclasses import dataclass, field
from typing import Optional, List
from dotenv import load_dotenv

# Load .env file from backend directory or project root
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))
load_dotenv()

@dataclass
class Config:
    REALITY_DEFENDER_API_KEY: str = ""
    GEMINI_API_KEY: str = ""
    INPUT_SIZE: tuple = (224, 224)

    TARGET_FRAMES: int = 100
    MAX_FRAMES: int = 120
    MIN_FACE_SIZE: int = 20

    # DIAGNOSTIC THRESHOLDS - Lowered to debug frame loss issue
    # Original: BLUR_VAR_THRESHOLD: float = 60.0
    # Original: BRIGHTNESS_MIN: float = 10.0
    # Original: FACE_SIZE_RATIO_MIN: float = 0.02
    # Original: QUALITY_SCORE_THRESHOLD: float = 0.4
    BLUR_VAR_THRESHOLD: float = 30.0
    BRIGHTNESS_MIN: float = 5.0
    BRIGHTNESS_MAX: float = 245.0
    FACE_SIZE_RATIO_MIN: float = 0.01
    FACE_SIZE_RATIO_MAX: float = 0.95
    HEAD_PITCH_THRESHOLD: float = 30.0
    HEAD_YAW_THRESHOLD: float = 30.0
    TEMPORAL_WINDOW_SIZE: int = 15
    STREAM_WINDOW_SIZE: int = 30
    STREAM_INFERENCE_INTERVAL_MS: int = 400
    CONFIDENCE_CALIBRATION_TEMP: float = 1.5  # Softens overconfident predictions
    DUPLICATE_FRAME_THRESHOLD: float = 0.92
    SCENE_CHANGE_THRESHOLD: float = 0.3
    MOTION_PEAK_THRESHOLD: float = 15.0
    MODEL_FALLBACK_PATHS: list = None
    ENABLE_RETINAFACE: bool = True
    ENABLE_SCRFD: bool = False  # Optional: scrfd_2.5g.onnx is missing
    ENABLE_MEDIAPIPE: bool = True
    ENABLE_MTCNN: bool = True

    AUDIO_TFLITE_ENABLED: bool = False  # Audio.tflite outputs 1.0 (constant function) on realistic inputs, so it is disabled from fusion score until retrained.
    CACHE_DIR: str = ""
    CACHE_ENABLED: bool = True
    MAX_VIDEO_SIZE_MB: int = 500
    URL_DOWNLOAD_TIMEOUT: int = 120
    REALITY_DEFENDER_TIMEOUT_SEC: int = 45
    # Seconds between result polls while Reality Defender models are still ANALYZING.
    REALITY_DEFENDER_POLL_INTERVAL_SEC: float = 2.0
    # Fraction of the regular confidence kept when the cloud result is partial.
    RD_PARTIAL_CONFIDENCE_FACTOR: float = 0.5
    FRAME_EXTRACTION_WORKERS: int = 4
    INFERENCE_BATCH_SIZE: int = 8
    USE_GPU_DELEGATE: bool = False

    def __post_init__(self):
        if not self.REALITY_DEFENDER_API_KEY:
            self.REALITY_DEFENDER_API_KEY = os.getenv("REALITY_DEFENDER_API_KEY", "")
        if not self.REALITY_DEFENDER_TIMEOUT_SEC:
            self.REALITY_DEFENDER_TIMEOUT_SEC = int(
                os.getenv("REALITY_DEFENDER_TIMEOUT_SEC", "45")
            )
        if not self.REALITY_DEFENDER_POLL_INTERVAL_SEC:
            self.REALITY_DEFENDER_POLL_INTERVAL_SEC = float(
                os.getenv("REALITY_DEFENDER_POLL_INTERVAL_SEC", "2.0")
            )
        if not self.GEMINI_API_KEY:
            self.GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
        if not self.GEMINI_API_KEY:
            logging.getLogger("veriframe.config").warning(
                "GEMINI_API_KEY is not set. Gemini explanations are disabled (falling back to plain template explanation)."
            )


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
