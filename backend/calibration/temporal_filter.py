import numpy as np
from typing import List, Dict
from collections import deque

class TemporalFilter:
    def __init__(self, window_size: int = 10):
        self.window_size = window_size
        self.scores_window: deque = deque(maxlen=window_size)
        self.raw_scores: List[float] = []

    def update(self, score: float) -> float:
        self.scores_window.append(score)
        self.raw_scores.append(score)
        if len(self.scores_window) < 2:
            return score
        arr = np.array(list(self.scores_window))
        median_score = float(np.median(arr))
        mean_score = float(np.mean(arr))
        smoothed = median_score * 0.6 + mean_score * 0.4
        return smoothed

    def get_aggregate(self) -> Dict[str, float]:
        if not self.raw_scores:
            return {"mean": 0.0, "median": 0.0, "std": 0.0, "min": 0.0, "max": 0.0}
        arr = np.array(self.raw_scores)
        return {
            "mean": float(np.mean(arr)),
            "median": float(np.median(arr)),
            "std": float(np.std(arr)),
            "min": float(np.min(arr)),
            "max": float(np.max(arr)),
        }

    def temporal_vote(self) -> str:
        if len(self.raw_scores) < 3:
            return "UNCERTAIN"
        recent = self.raw_scores[-min(len(self.raw_scores), self.window_size):]
        arr = np.array(recent)
        median_score = float(np.median(arr))
        if median_score >= 0.8:
            return "FAKE"
        elif median_score >= 0.6:
            return "LIKELY_FAKE"
        elif median_score >= 0.4:
            return "UNCERTAIN"
        elif median_score >= 0.2:
            return "LIKELY_REAL"
        else:
            return "REAL"

    def reset(self):
        self.scores_window.clear()
        self.raw_scores.clear()
