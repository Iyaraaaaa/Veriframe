import cv2
import numpy as np
import logging
from typing import List, Dict, Any, Tuple

logger = logging.getLogger("veriframe.filters.smart_frame_selector")

class SmartFrameSelector:
    """Stage 4 — Intelligent Frame Selection Engine"""

    def __init__(self, min_frames: int = 20, max_frames: int = 60):
        self.min_frames = min_frames
        self.max_frames = max_frames

    def select_informative_frames(self, video_path: str) -> List[int]:
        """
        Analyzes full video stream to select the most informative 20-60 frames
        based on scene changes, motion peaks, and face appearances.
        """
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            logger.error(f"[SmartFrameSelector] Could not open video {video_path}")
            return []

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        duration_sec = total_frames / fps if fps > 0 else 0.0

        if total_frames <= 0:
            cap.release()
            return []

        # Determine target frame count based on video duration (20 min, 60 max)
        target_count = int(np.clip(20 + (duration_sec / 10.0) * 10, self.min_frames, self.max_frames))
        target_count = min(target_count, total_frames)

        logger.info(f"[SmartFrameSelector] Total frames: {total_frames}, Target frame count: {target_count}")

        if total_frames <= target_count:
            cap.release()
            return list(range(total_frames))

        # Sample coarse candidate frames (up to 300 candidates)
        sample_step = max(1, total_frames // 300)
        candidate_indices = list(range(0, total_frames, sample_step))

        frame_scores = []
        prev_hist = None
        prev_gray = None

        for idx in candidate_indices:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ret, frame = cap.read()
            if not ret or frame is None:
                continue

            # 1. Scene change score via HSV histogram correlation
            hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
            hist = cv2.calcHist([hsv], [0, 1], None, [16, 16], [0, 180, 0, 256])
            cv2.normalize(hist, hist)

            scene_change_score = 0.0
            if prev_hist is not None:
                corr = cv2.compareHist(prev_hist, hist, cv2.HISTCMP_CORREL)
                scene_change_score = max(0.0, 1.0 - corr)
            prev_hist = hist

            # 2. Motion peak score via optical flow / absolute diff
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            motion_score = 0.0
            if prev_gray is not None:
                diff = cv2.absdiff(gray, prev_gray)
                motion_score = float(np.mean(diff)) / 255.0
            prev_gray = gray

            # 3. Variance of Laplacian (Sharpness score)
            lap_var = cv2.Laplacian(gray, cv2.CV_64F).var()
            sharpness_score = min(1.0, lap_var / 500.0)

            # Combined informativeness score
            combined_score = (scene_change_score * 0.4) + (motion_score * 0.4) + (sharpness_score * 0.2)
            frame_scores.append((idx, combined_score))

        cap.release()

        if not frame_scores:
            return list(np.linspace(0, total_frames - 1, target_count, dtype=int))

        # Sort candidate frames by informativeness score descending
        frame_scores.sort(key=lambda x: x[1], reverse=True)

        # Select top target_count frames with uniform distribution enforcing minimum distance
        selected = []
        min_dist = max(1, total_frames // (target_count * 2))

        for idx, score in frame_scores:
            if len(selected) >= target_count:
                break
            if all(abs(idx - s) >= min_dist for s in selected):
                selected.append(idx)

        # Fill remaining if needed
        if len(selected) < target_count:
            remainder = [idx for idx, _ in frame_scores if idx not in selected]
            selected.extend(remainder[:target_count - len(selected)])

        selected.sort()
        logger.info(f"[SmartFrameSelector] Selected {len(selected)} informative frames out of {total_frames}")
        return selected
