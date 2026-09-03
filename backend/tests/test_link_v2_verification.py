import unittest
import numpy as np
import cv2
import os
import sys
import tempfile
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pipelines.video_pipeline import VideoPipeline
from pipelines.link_verification_v2 import LinkVerificationV2, interpret_model_output
from detectors.face_detector import FaceDetector, FaceDetectionResult
from filters.frame_sampler import AdaptiveFrameSampler
from filters.quality_filter import QualityFilter, FaceQualityConfig
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor

class DummyInterpreter:
    def __init__(self, val: float = 0.88):
        self.output_val = val
    def get_input_details(self):
        return [{"index": 0, "shape": [1, 224, 224, 3]}]
    def get_output_details(self):
        return [{"index": 0}]
    def set_tensor(self, index, tensor):
        pass
    def invoke(self):
        pass
    def get_tensor(self, index):
        return np.array([[self.output_val]], dtype=np.float32)

class TestLinkV2Verification(unittest.TestCase):
    def setUp(self):
        self.interpreter_fake = DummyInterpreter(val=0.88)
        self.interpreter_real = DummyInterpreter(val=0.12)
        
        self.face_detector = MagicMock(spec=FaceDetector)
        dummy_face = np.zeros((100, 100, 3), dtype=np.uint8)
        cv2.circle(dummy_face, (50, 50), 30, (200, 200, 200), -1)

        self.face_detector.detect.return_value = [
            FaceDetectionResult(
                face_crop=dummy_face,
                box=[10, 10, 80, 80],
                quality_score=0.9,
                detector="mock",
            )
        ]

        self.frame_sampler = MagicMock(spec=AdaptiveFrameSampler)
        self.frame_sampler.sample.return_value = [0, 5, 10]

        self.quality_filter = MagicMock(spec=QualityFilter)
        self.quality_filter.is_quality_face.return_value = (True, {"quality_score": 0.9})

        self.temporal_filter = TemporalFilter(window_size=5)
        self.calibrator = ConfidenceCalibrator(temperature=1.0)
        self.preprocessor = FramePreprocessor(target_size=(224, 224))

        self.tmp_video = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
        fourcc = cv2.VideoWriter_fourcc(*"mp4v")
        out = cv2.VideoWriter(self.tmp_video.name, fourcc, 10.0, (320, 240))
        for _ in range(15):
            frame = np.zeros((240, 320, 3), dtype=np.uint8)
            cv2.circle(frame, (160, 120), 40, (255, 255, 255), -1)
            out.write(frame)
        out.release()

    def tearDown(self):
        if os.path.exists(self.tmp_video.name):
            try:
                os.remove(self.tmp_video.name)
            except Exception:
                pass

    def test_known_real_and_fake_comparison(self):
        # 1. Real sample local upload vs link
        v2_real = LinkVerificationV2(
            interpreter=self.interpreter_real,
            input_details=self.interpreter_real.get_input_details(),
            output_details=self.interpreter_real.get_output_details(),
            face_detector=self.face_detector,
            frame_sampler=self.frame_sampler,
            quality_filter=self.quality_filter,
            preprocessor=self.preprocessor,
        )
        v2_real.download_video = MagicMock(return_value={"success": True, "video_path": self.tmp_video.name, "content_length_mb": 1.0, "reason": None})
        res_real_link = v2_real.process("https://example.com/real_video.mp4")

        # 2. Fake sample local upload vs link
        v2_fake = LinkVerificationV2(
            interpreter=self.interpreter_fake,
            input_details=self.interpreter_fake.get_input_details(),
            output_details=self.interpreter_fake.get_output_details(),
            face_detector=self.face_detector,
            frame_sampler=self.frame_sampler,
            quality_filter=self.quality_filter,
            preprocessor=self.preprocessor,
        )
        v2_fake.download_video = MagicMock(return_value={"success": True, "video_path": self.tmp_video.name, "content_length_mb": 1.0, "reason": None})
        res_fake_link = v2_fake.process("https://example.com/fake_video.mp4")

        # Confirm Link V2 correctly differentiates Real vs Fake based strictly on AI model output
        self.assertIn(res_real_link["fineVerdict"], ("REAL", "LIKELY_REAL"))
        self.assertAlmostEqual(res_real_link["raw_model_probability"], 0.12, places=2)

        self.assertIn(res_fake_link["fineVerdict"], ("FAKE", "LIKELY_FAKE"))
        self.assertAlmostEqual(res_fake_link["raw_model_probability"], 0.88, places=2)

if __name__ == "__main__":
    unittest.main()
