import cv2
import numpy as np
import time
import logging
from typing import List, Dict, Any, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

from utils.video import get_video_metadata
from utils.image import resize_face, pad_to_square, compute_face_quality_score

logger = logging.getLogger("veriframe.pipelines.offline")

class OfflinePipeline:
    def __init__(self, interpreter, input_details, output_details):
        self.interpreter = interpreter
        self.input_details = input_details
        self.output_details = output_details

    def process(self, video_path: str, frame_timestamps_ms: List[int], on_progress=None) -> Dict[str, Any]:
        start_time = time.time()
        logger.info(f"[OfflinePipeline] Processing local video: {video_path}")

        scores = []
        boxes = []
        total = len(frame_timestamps_ms)

        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = {}
            for i, ts in enumerate(frame_timestamps_ms):
                futures[executor.submit(self._process_frame, video_path, ts)] = i

            for i, future in enumerate(as_completed(futures)):
                idx = futures[future]
                try:
                    score, box = future.result()
                    if score is not None:
                        scores.append(score)
                        boxes.append(box)
                except Exception as e:
                    logger.debug(f"[OfflinePipeline] Frame {idx} error: {e}")
                if on_progress:
                    on_progress(0.3 + (i + 1) / total * 0.5)

        if not scores:
            raise ValueError("On-device verification failed: Could not extract quality frames from video.")

        avg_score = float(np.mean(scores))
        authenticity_score = round(avg_score * 100.0, 2)
        fake_probability = round((1.0 - avg_score) * 100.0, 2)

        if len(scores) > 1:
            variance = float(np.var(scores))
            frame_consistency = round(max(0.0, (1.0 - variance) * 100.0), 2)
        else:
            frame_consistency = 100.0

        prediction_confidence = avg_score if avg_score >= 0.5 else (1.0 - avg_score)
        fused_confidence = round(
            (prediction_confidence * 0.7 + (frame_consistency / 100.0) * 0.15 + 0.9 * 0.15) * 100.0,
            2,
        )

        verdict = "AUTHENTIC" if authenticity_score >= 50.0 else "MANIPULATED"
        risk_level = "LOW" if authenticity_score >= 75.0 else ("MEDIUM" if authenticity_score >= 50.0 else "HIGH")
        processing_time = time.time() - start_time

        logger.info(f"[OfflinePipeline] Completed in {processing_time:.2f}s. Verdict: {verdict}")

        return {
            "authenticityScore": authenticity_score,
            "fakeProbability": fake_probability,
            "confidence": fused_confidence,
            "frameConsistency": frame_consistency,
            "verdict": verdict,
            "riskLevel": risk_level,
            "faces_analyzed": len(scores),
            "processing_time_sec": round(processing_time, 2),
        }

    def _process_frame(self, video_path: str, timestamp_ms: int) -> tuple:
        cap = cv2.VideoCapture(video_path)
        cap.set(cv2.CAP_PROP_POS_MSEC, timestamp_ms)
        ret, frame = cap.read()
        cap.release()
        if not ret or frame is None:
            return None, None

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        haar_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        face_cascade = cv2.CascadeClassifier(haar_path)
        detected = face_cascade.detectMultiScale(gray, 1.1, 5)
        if detected is None or len(detected) == 0:
            return None, None

        x, y, w, h = max(detected, key=lambda b: b[2] * b[3])
        face_crop = frame[y:y+h, x:x+w]
        quality_score, _ = compute_face_quality_score(face_crop)

        if quality_score < 0.3:
            return None, None

        try:
            resized = resize_face(pad_to_square(face_crop), self.input_details[0]["shape"][1:3])
        except Exception:
            resized = cv2.resize(face_crop, (224, 224))

        resized = resized.astype(np.float32)
        resized = np.expand_dims(resized, axis=0)
        self.interpreter.set_tensor(self.input_details[0]["index"], resized)
        self.interpreter.invoke()
        output = self.interpreter.get_tensor(self.output_details[0]["index"])
        score = float(output[0][0])
        return score, (x, y, w, h)
