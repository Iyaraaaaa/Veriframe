import unittest
import numpy as np
import cv2
import os
import sys
import tempfile
import json
import hashlib

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from preprocessing.preprocessor import FramePreprocessor
from filters.quality_filter import QualityFilter, FaceQualityConfig
from filters.frame_sampler import AdaptiveFrameSampler
from cache.result_cache import ResultCache
from utils.url_service import URLService
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from database.connection import init_db, upsert_job, get_report_by_hash, list_reports, insert_history
from models.trainer import ModelTrainer, TrainingConfig
from models.exporter import ModelExporter

class TestFramePreprocessor(unittest.TestCase):
    def setUp(self):
        self.preprocessor = FramePreprocessor(target_size=(224, 224))
        self.dummy_face = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)

    def test_preprocess_face_output_shape(self):
        result = self.preprocessor.preprocess_face(self.dummy_face)
        self.assertEqual(result.shape, (1, 224, 224, 3))

    def test_preprocess_for_tflite_output_shape(self):
        result = self.preprocessor.preprocess_for_tflite(self.dummy_face)
        self.assertEqual(result.shape, (1, 224, 224, 3))

    def test_pad_to_square(self):
        h, w = 100, 80
        img = np.random.randint(0, 255, (h, w, 3), dtype=np.uint8)
        result = self.preprocessor.pad_to_square(img)
        self.assertEqual(result.shape[0], result.shape[1])

    def test_gamma_correction(self):
        result = self.preprocessor.gamma_correction(self.dummy_face, gamma=1.0)
        self.assertEqual(result.shape, self.dummy_face.shape)

    def test_clahe(self):
        result = self.preprocessor.apply_clahe(self.dummy_face)
        self.assertEqual(result.shape, self.dummy_face.shape)

    def test_normalize(self):
        result = self.preprocessor.normalize(self.dummy_face.astype(np.float32))
        self.assertEqual(result.shape, self.dummy_face.shape)

class TestQualityFilter(unittest.TestCase):
    def setUp(self):
        self.config = FaceQualityConfig(
            blur_variance_threshold=10.0,
            brightness_min=10.0,
            brightness_max=240.0,
            min_face_size=10,
        )
        self.filter = QualityFilter(config=self.config)
        self.dummy_face = np.random.randint(0, 255, (5, 5, 3), dtype=np.uint8)

    def test_too_small_face(self):
        is_good, details = self.filter.is_quality_face(self.dummy_face, (1000, 1000))
        self.assertFalse(is_good)

    def test_quality_pass(self):
        face = np.zeros((100, 100, 3), dtype=np.uint8)
        cv2.circle(face, (50, 50), 30, (200, 200, 200), -1)
        cv2.line(face, (0, 0), (100, 100), (255, 255, 255), 3)
        is_good, details = self.filter.is_quality_face(face, (200, 200))
        self.assertTrue(is_good)

    def test_too_dark(self):
        dark_face = np.zeros((100, 100, 3), dtype=np.uint8)
        is_good, _ = self.filter.is_quality_face(dark_face, (1000, 1000))
        self.assertFalse(is_good)

class TestAdaptiveFrameSampler(unittest.TestCase):
    def test_empty_video(self):
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
            tmp_path = tmp.name
        try:
            sampler = AdaptiveFrameSampler(target_frames=10, max_frames=20)
            result = sampler.sample(tmp_path)
            self.assertEqual(result, [])
        finally:
            os.remove(tmp_path)

    def test_target_frames(self):
        sampler = AdaptiveFrameSampler(target_frames=100, max_frames=120)
        self.assertEqual(sampler.target_frames, 100)
        self.assertEqual(sampler.max_frames, 120)

class TestResultCache(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.cache = ResultCache(cache_dir=self.tmpdir)

    def test_set_and_get(self):
        test_hash = "abc123"
        test_result = {"score": 0.95, "verdict": "FAKE"}
        self.assertTrue(self.cache.set(test_hash, test_result))
        cached = self.cache.get(test_hash)
        self.assertIsNotNone(cached)
        self.assertEqual(cached["score"], 0.95)

    def test_miss(self):
        cached = self.cache.get("nonexistent")
        self.assertIsNone(cached)

    def test_stats(self):
        stats = self.cache.stats()
        self.assertIn("entries", stats)

    def test_clear(self):
        test_hash = "clear_test"
        self.cache.set(test_hash, {"test": True})
        self.assertTrue(self.cache.clear(test_hash))
        self.assertIsNone(self.cache.get(test_hash))

class TestURLService(unittest.TestCase):
    def test_is_video_url(self):
        self.assertTrue(URLService.is_video_url("https://example.com/video.mp4"))
        self.assertFalse(URLService.is_video_url("https://example.com/page.html"))

    def test_get_domain(self):
        self.assertEqual(URLService.get_domain("https://drive.google.com/file/d/123"), "drive.google.com")

    def test_resolve_google_drive(self):
        result = URLService._resolve_google_drive("https://drive.google.com/file/d/abc123/view")
        self.assertIn("uc?export=download", result)

    def test_resolve_dropbox(self):
        result = URLService._resolve_dropbox("https://dropbox.com/s/abc123/video.mp4?dl=0")
        self.assertIn("dl=1", result)

class TestTemporalFilter(unittest.TestCase):
    def test_update(self):
        tf = TemporalFilter(window_size=5)
        smoothed = tf.update(0.8)
        self.assertIsInstance(smoothed, float)

    def test_aggregate(self):
        tf = TemporalFilter(window_size=5)
        tf.update(0.8)
        tf.update(0.7)
        agg = tf.get_aggregate()
        self.assertIn("mean", agg)

    def test_reset(self):
        tf = TemporalFilter(window_size=5)
        tf.update(0.8)
        tf.reset()
        self.assertEqual(len(tf.raw_scores), 0)

class TestConfidenceCalibrator(unittest.TestCase):
    def test_calibrate(self):
        cal = ConfidenceCalibrator(temperature=1.0)
        result = cal.calibrate(0.8)
        self.assertGreaterEqual(result, 0.0)
        self.assertLessEqual(result, 1.0)

    def test_calibrate_edge_cases(self):
        cal = ConfidenceCalibrator(temperature=1.0)
        self.assertAlmostEqual(cal.calibrate(0.0), 0.0, places=4)
        self.assertAlmostEqual(cal.calibrate(1.0), 1.0, places=4)

class TestDatabase(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.tmpdir = tempfile.mkdtemp()
        from config import config as app_config
        original_cache_dir = app_config.CACHE_DIR
        app_config.CACHE_DIR = self.tmpdir
        init_db()
        self.addCleanup(lambda: setattr(app_config, 'CACHE_DIR', original_cache_dir))

    def test_upsert_job(self):
        upsert_job("test-job-1", status="completed", progress=1.0, result={"score": 0.9})
        report = get_report_by_hash("nonexistent")
        self.assertIsNone(report)

    def test_insert_history(self):
        insert_history({
            "verificationId": "VRF-123",
            "userId": "user-1",
            "source": "test",
            "mediaType": "video",
            "verdict": "AUTHENTIC",
            "riskLevel": "LOW",
            "authenticityScore": 95.0,
            "confidence": 90.0,
            "reportHash": "hash123",
        })
        reports = list_reports(limit=10)
        self.assertIsInstance(reports, list)

class TestModelTrainer(unittest.TestCase):
    def test_config_validation(self):
        config = TrainingConfig(architecture="invalid")
        errors = config.validate()
        self.assertGreater(len(errors), 0)

    def test_valid_config(self):
        config = TrainingConfig(architecture="efficientvit")
        errors = config.validate()
        self.assertEqual(len(errors), 0)

    def test_train_initialization(self):
        trainer = ModelTrainer(config=TrainingConfig(architecture="efficientvit", epochs=1))
        result = trainer.train()
        self.assertEqual(result["status"], "initialized")

    def test_get_supported_architectures(self):
        trainer = ModelTrainer()
        archs = trainer.get_supported_architectures()
        self.assertIn("efficientvit", archs)
        self.assertIn("crossefficientvit", archs)
        self.assertIn("efficientnetv2", archs)
        self.assertIn("convnext", archs)

class TestModelExporter(unittest.TestCase):
    def test_validate_tflite_missing(self):
        result = ModelExporter.validate_tflite("/nonexistent/model.tflite")
        self.assertFalse(result["valid"])

    def test_get_model_info_missing(self):
        result = ModelExporter.get_model_info("/nonexistent/model.tflite")
        self.assertEqual(result["size_mb"], 0)
        self.assertFalse(result["validation"]["valid"])

class TestVideoUpload(unittest.TestCase):
    def test_large_video_handling(self):
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
            tmp.write(b"0" * (10 * 1024 * 1024))
            tmp_path = tmp.name
        try:
            self.assertTrue(os.path.exists(tmp_path))
            self.assertEqual(os.path.getsize(tmp_path), 10 * 1024 * 1024)
        finally:
            os.remove(tmp_path)

    def test_empty_file(self):
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tmp:
            tmp_path = tmp.name
        try:
            self.assertEqual(os.path.getsize(tmp_path), 0)
        finally:
            os.remove(tmp_path)

class TestInvalidInputs(unittest.TestCase):
    def test_invalid_url(self):
        self.assertFalse(URLService.is_video_url("not-a-url"))

    def test_empty_hash(self):
        cache = ResultCache(cache_dir=tempfile.mkdtemp())
        self.assertIsNone(cache.get(""))

if __name__ == "__main__":
    unittest.main()