import cv2
import numpy as np
import time
import logging
from typing import List, Dict, Any
from concurrent.futures import ThreadPoolExecutor, as_completed

from config import config as app_config
from detectors.face_detector import FaceDetector, FaceDetectionResult
from filters.frame_sampler import AdaptiveFrameSampler
from filters.quality_filter import QualityFilter, FaceQualityConfig
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from preprocessing.preprocessor import FramePreprocessor
from utils.image import resize_face, pad_to_square

logger = logging.getLogger("veriframe.pipelines.video")

class VideoPipeline:
    def __init__(
        self,
        interpreter,
        input_details,
        output_details,
        face_detector: FaceDetector,
        frame_sampler: AdaptiveFrameSampler,
        quality_filter: QualityFilter,
        temporal_filter: TemporalFilter,
        calibrator: ConfidenceCalibrator,
        preprocessor: FramePreprocessor,
    ):
        self.interpreter = interpreter
        self.input_details = input_details
        self.output_details = output_details
        self.face_detector = face_detector
        self.frame_sampler = frame_sampler
        self.quality_filter = quality_filter
        self.temporal_filter = temporal_filter
        self.calibrator = calibrator
        self.preprocessor = preprocessor

    def process(self, video_path: str) -> Dict[str, Any]:
        start_time = time.time()
        logger.info(f"[VideoPipeline] Processing video: {video_path}")

        frame_indices = self.frame_sampler.sample(video_path)
        logger.info(f"[VideoPipeline] Selected {len(frame_indices)} frames")

        if not frame_indices:
            raise ValueError("No suitable frames extracted from video.")

        cap = cv2.VideoCapture(video_path)
        frame_results: List[Dict[str, Any]] = []

        for idx in frame_indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ret, frame = cap.read()
            if not ret:
                continue
            detections = self.face_detector.detect(frame)
            if not detections:
                logger.debug(f"[VideoPipeline] No face detected at frame {idx}")
                continue
            frame_results.append({
                "frame_index": idx,
                "frame": frame,
                "detections": detections,
            })
        cap.release()

        all_face_crops = []
        all_boxes = []
        all_quality_scores = []
        all_detectors = []

        for fr in frame_results:
            for det in fr["detections"]:
                is_good, details = self.quality_filter.is_quality_face(det.face_crop, fr["frame"].shape)
                if is_good:
                    all_face_crops.append(det.face_crop)
                    all_boxes.append(det.box)
                    all_quality_scores.append(det.quality_score)
                    all_detectors.append(det.detector)

        if not all_face_crops:
            raise ValueError("No quality faces detected in video.")

        logger.info(f"[VideoPipeline] {len(all_face_crops)} quality faces after filtering")

        scores = self._run_batch_inference(all_face_crops)

        weighted_scores = []
        for i, score in enumerate(scores):
            weight = all_quality_scores[i]
            weighted_scores.append(score * weight)

        avg_weighted_score = sum(weighted_scores) / sum(all_quality_scores) if sum(all_quality_scores) > 0 else float(np.mean(scores))
        calibrated_score = self.calibrator.calibrate(avg_weighted_score)

        for score in scores:
            self.temporal_filter.update(score)

        temporal_agg = self.temporal_filter.get_aggregate()
        verdict = self._adaptive_verdict(calibrated_score)

        processing_time = time.time() - start_time
        logger.info(f"[VideoPipeline] Completed in {processing_time:.2f}s. Verdict: {verdict}")

        return {
            "raw_score": round(avg_weighted_score, 4),
            "calibrated_score": round(calibrated_score, 4),
            "authenticity_score": round(calibrated_score * 100.0, 2),
            "fake_probability": round((1.0 - calibrated_score) * 100.0, 2),
            "verdict": verdict,
            "temporal": temporal_agg,
            "faces_analyzed": len(all_face_crops),
            "frames_with_faces": len(frame_results),
            "processing_time_sec": round(processing_time, 2),
        }

    def _run_batch_inference(self, face_crops: List[np.ndarray]) -> List[float]:
        scores = []
        with ThreadPoolExecutor(max_workers=app_config.FRAME_EXTRACTION_WORKERS) as executor:
            futures = []
            for crop in face_crops:
                try:
                    processed = self.preprocessor.preprocess_for_tflite(crop)
                except Exception:
                    try:
                        resized = resize_face(pad_to_square(crop), self.input_details[0]["shape"][1:3])
                        processed = self.preprocessor.preprocess_for_tflite(resized)
                    except Exception:
                        processed = None
                if processed is not None:
                    futures.append(executor.submit(self._infer_single, processed))
                else:
                    scores.append(0.5)
            for future in as_completed(futures):
                try:
                    scores.append(future.result())
                except Exception as e:
                    logger.debug(f"[VideoPipeline] Inference error: {e}")
                    scores.append(0.5)
        return scores

    def _infer_single(self, processed_face: np.ndarray) -> float:
        self.interpreter.set_tensor(self.input_details[0]["index"], processed_face)
        self.interpreter.invoke()
        output = self.interpreter.get_tensor(self.output_details[0]["index"])
        return float(output[0][0])

    def _adaptive_verdict(self, score: float) -> str:
        if score >= 0.8:
            return "FAKE"
        elif score >= 0.6:
            return "LIKELY_FAKE"
        elif score >= 0.4:
            return "UNCERTAIN"
        elif score >= 0.2:
            return "LIKELY_REAL"
        else:
            return "REAL"