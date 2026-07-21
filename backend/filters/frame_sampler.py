import cv2
import numpy as np
from typing import List, Tuple
from utils.video import compute_frame_diff_hist, compute_optical_flow_magnitude

class AdaptiveFrameSampler:
    def __init__(self, target_frames: int = 100, max_frames: int = 120):
        self.target_frames = target_frames
        self.max_frames = max_frames
        self.duplicate_threshold = 0.92

    def sample(self, video_path: str) -> List[int]:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return []

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if total_frames <= 0:
            cap.release()
            return []

        candidates = self._generate_candidates(total_frames)
        scored = self._score_frames(cap, candidates)
        cap.release()

        selected = self._select_diverse_frames(scored)
        return selected[:self.max_frames]

    def _generate_candidates(self, total_frames: int) -> List[int]:
        candidates = set()
        n = total_frames
        if n == 0:
            return []
        if n == 1:
            return [0]

        candidates.add(0)
        candidates.add(n - 1)
        mid = n // 2
        candidates.add(mid)

        step = max(1, n // self.target_frames)
        for i in range(0, n, step):
            candidates.add(min(i, n - 1))

        interval = max(1, n // 8)
        for i in range(interval, n, interval):
            candidates.add(min(i, n - 1))

        return sorted(list(candidates))

    def _score_frames(self, cap, candidates: List[int]) -> List[Tuple[int, float, float]]:
        scored = []
        prev_frame = None
        for idx in candidates:
            cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
            ret, frame = cap.read()
            if not ret or frame is None:
                continue

            is_blurry = self._is_blurry(frame)
            is_dark = self._is_dark(frame)
            if is_blurry or is_dark:
                continue

            if prev_frame is not None:
                try:
                    corr = compute_frame_diff_hist(prev_frame, frame)
                    if corr > self.duplicate_threshold:
                        continue
                except Exception:
                    pass

            sharpness = self._compute_sharpness(frame)
            motion = 0.0
            scene_change = 0.0
            if prev_frame is not None:
                try:
                    motion = compute_optical_flow_magnitude(prev_frame, frame)
                    scene_change = 1.0 - compute_frame_diff_hist(prev_frame, frame)
                except Exception:
                    pass
            prev_frame = frame

            score = sharpness * 0.5 + motion * 0.3 + scene_change * 0.2
            scored.append((idx, score, motion))
        return scored

    def _select_diverse_frames(self, scored: List[Tuple[int, float, float]]) -> List[int]:
        if not scored:
            return []
        if len(scored) <= self.target_frames:
            return [idx for idx, _, _ in scored]

        scored.sort(key=lambda x: x[1], reverse=True)
        selected = []
        min_gap = max(2, len(scored) // (self.target_frames * 2))
        for idx, score, motion in scored:
            if len(selected) >= self.max_frames:
                break
            too_close = any(abs(idx - s) < min_gap for s in selected)
            if not too_close:
                selected.append(idx)
        if not selected:
            selected = [idx for idx, _, _ in scored[:self.target_frames]]
        return selected

    def _is_blurry(self, frame: np.ndarray) -> bool:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        lap_var = cv2.Laplacian(gray, cv2.CV_64F).var()
        return lap_var < 100.0

    def _is_dark(self, frame: np.ndarray) -> bool:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        return float(np.mean(gray)) < 25.0

    def _compute_sharpness(self, frame: np.ndarray) -> float:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        lap_var = cv2.Laplacian(gray, cv2.CV_64F).var()
        return min(1.0, lap_var / 500.0)