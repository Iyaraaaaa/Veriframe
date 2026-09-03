import unittest
import numpy as np
import cv2
import os
import sys
import tempfile
import time
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pipelines.video_pipeline import VideoPipeline
from pipelines.link_pipeline import LinkPipeline
from pipelines.link_verification_v2 import LinkVerificationV2, interpret_model_output
from pipelines.stream_pipeline import StreamPipeline
from pipelines.offline_pipeline import OfflinePipeline
from detectors.face_detector import FaceDetector, FaceDetectionResult
from filters.frame_sampler import AdaptiveFrameSampler
from filters.quality_filter import QualityFilter, FaceQualityConfig
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor

class DummyInterpreter:
    def __init__(self):
        self.output_val = 0.85
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

class TestPipelines(unittest.TestCase):
    def setUp(self):
        self.interpreter = DummyInterpreter()
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()

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

        # Create temporary video file for test runs
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

    def test_local_video_pipeline(self):
        pipeline = VideoPipeline(
            interpreter=self.interpreter,
            input_details=self.input_details,
            output_details=self.output_details,
            face_detector=self.face_detector,
            frame_sampler=self.frame_sampler,
            quality_filter=self.quality_filter,
            temporal_filter=self.temporal_filter,
            calibrator=self.calibrator,
            preprocessor=self.preprocessor,
        )
        res = pipeline.process(self.tmp_video.name, source="Local Upload")
        self.assertEqual(res["source"], "Local Upload")
        self.assertIn("authenticityScore", res)
        self.assertIn("verdict", res)
        self.assertIn("detectedEvidence", res)
        self.assertIn("forensicObservations", res)
        self.assertTrue(res["verificationId"].startswith("VRF-LOC-"))

    def test_stream_pipeline_flow(self):
        pipeline = StreamPipeline(
            interpreter=self.interpreter,
            input_details=self.input_details,
            output_details=self.output_details,
            face_detector=self.face_detector,
            quality_filter=self.quality_filter,
            temporal_filter=self.temporal_filter,
            calibrator=self.calibrator,
            preprocessor=self.preprocessor,
        )
        session = pipeline.create_session("rtsp://test-stream-url")
        self.assertEqual(session["stream_url"], "rtsp://test-stream-url")

        dummy_frame = np.zeros((240, 320, 3), dtype=np.uint8)
        frame_res = pipeline.process_frame(session, dummy_frame)
        self.assertIn("session_confidence_score", frame_res)
        self.assertEqual(session["faces_detected"], 1)

        summary = pipeline.get_session_summary(session)
        self.assertEqual(summary["status"], "completed")
        self.assertIn("authenticityScore", summary["result"])
        self.assertTrue(summary["result"]["verificationId"].startswith("VRF-STR-"))

    def test_link_pipeline(self):
        pipeline = LinkPipeline(
            interpreter=self.interpreter,
            input_details=self.input_details,
            output_details=self.output_details,
            face_detector=self.face_detector,
            frame_sampler=self.frame_sampler,
            quality_filter=self.quality_filter,
            temporal_filter=self.temporal_filter,
            calibrator=self.calibrator,
            preprocessor=self.preprocessor,
        )
        pipeline.v2_pipeline.download_video = MagicMock(return_value={"success": True, "video_path": self.tmp_video.name, "content_length_mb": 1.5, "reason": None})
        res = pipeline.process("https://drive.google.com/file/d/test1234/view", source="Video Link")
        self.assertEqual(res["source"], "Video Link")
        self.assertEqual(res["domain"], "drive.google.com")
        self.assertIn("authenticityScore", res)
        self.assertTrue(res["verificationId"].startswith("VRF-LNK-V2-"))

    def test_link_v2_download_failure_produces_inconclusive(self):
        v2 = LinkVerificationV2(
            interpreter=self.interpreter,
            input_details=self.input_details,
            output_details=self.output_details,
            face_detector=self.face_detector,
            frame_sampler=self.frame_sampler,
            quality_filter=self.quality_filter,
        )
        v2.download_video = MagicMock(return_value={"success": False, "video_path": None, "content_length_mb": 0.0, "reason": "HTTP 404 Not Found"})
        res = v2.process("https://youtube.com/watch?v=nonexistent")
        self.assertEqual(res["verdict"], "INCONCLUSIVE")
        self.assertEqual(res["analysis_status"], "DOWNLOAD_FAILED")
        self.assertIsNone(res["raw_model_probability"])
        self.assertIsNone(res["aggregated_probability"])
        self.assertFalse(res["video_retrieved"])

    def test_link_v2_no_faces_produces_inconclusive(self):
        v2 = LinkVerificationV2(
            interpreter=self.interpreter,
            input_details=self.input_details,
            output_details=self.output_details,
            face_detector=self.face_detector,
            frame_sampler=self.frame_sampler,
            quality_filter=self.quality_filter,
        )
        v2.download_video = MagicMock(return_value={"success": True, "video_path": self.tmp_video.name, "content_length_mb": 1.5, "reason": None})
        v2.detect_and_filter_faces = MagicMock(return_value={"valid_face_crops": [], "total_faces_detected": 0, "boxes": []})
        res = v2.process("https://youtube.com/watch?v=nature_video")
        self.assertEqual(res["verdict"], "INCONCLUSIVE")
        self.assertEqual(res["analysis_status"], "NO_USABLE_FACES")
        self.assertIsNone(res["raw_model_probability"])
        self.assertIsNone(res["aggregated_probability"])
        self.assertTrue(res["video_retrieved"])

    def test_model_output_interpretation(self):
        interp_real = interpret_model_output(0.12)
        self.assertAlmostEqual(interp_real["fake_probability"], 0.12)
        self.assertAlmostEqual(interp_real["real_probability"], 0.88)

        interp_fake = interpret_model_output(0.91)
        self.assertAlmostEqual(interp_fake["fake_probability"], 0.91)
        self.assertAlmostEqual(interp_fake["real_probability"], 0.09)

    def test_offline_pipeline(self):
        pipeline = OfflinePipeline(
            interpreter=self.interpreter,
            input_details=self.input_details,
            output_details=self.output_details,
        )
        pipeline._process_frame = MagicMock(return_value=(0.85, (10, 10, 80, 80)))
        res = pipeline.process(self.tmp_video.name, frame_timestamps_ms=[0, 100, 200])
        self.assertIn("authenticityScore", res)
        self.assertIn("verdict", res)

if __name__ == "__main__":
    unittest.main()

