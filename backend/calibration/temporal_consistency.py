import numpy as np
import logging
from typing import List, Dict, Any

logger = logging.getLogger("veriframe.calibration.temporal_consistency")

class TemporalConsistencyAnalyzer:
    """Stage 10 — Temporal Consistency Engine"""

    def __init__(self, window_size: int = 15):
        self.window_size = window_size
        self.score_history: List[float] = []

    def reset(self):
        self.score_history.clear()

    def add_score(self, score: float):
        self.score_history.append(score)

    def analyze(self) -> Dict[str, Any]:
        """
        Calculates inter-frame prediction variance, flickering score, identity drift,
        and temporal consistency index (0-100).
        """
        if not self.score_history:
            return {
                "consistency_score": 100.0,
                "flicker_index": 0.0,
                "variance": 0.0,
                "smoothed_score": 0.5,
                "is_stable": True,
            }

        scores = np.array(self.score_history, dtype=np.float32)
        mean_score = float(np.mean(scores))
        std_dev = float(np.std(scores))
        variance = float(np.var(scores))

        # Flickering calculation: sum of absolute frame-to-frame differences
        if len(scores) >= 2:
            diffs = np.abs(np.diff(scores))
            flicker_index = float(np.mean(diffs))
        else:
            flicker_index = 0.0

        # Weighted temporal smoothing (recent frames weighted higher)
        weights = np.exp(np.linspace(-1.0, 0.0, len(scores)))
        weights /= np.sum(weights)
        smoothed_score = float(np.sum(scores * weights))

        # Consistency score (100 = perfectly smooth & consistent predictions across frames)
        consistency_score = max(0.0, 100.0 - (flicker_index * 150.0 + std_dev * 100.0))

        is_stable = flicker_index < 0.15 and std_dev < 0.20

        return {
            "consistency_score": round(consistency_score, 2),
            "flicker_index": round(flicker_index, 4),
            "std_dev": round(std_dev, 4),
            "variance": round(variance, 4),
            "smoothed_score": round(smoothed_score, 4),
            "is_stable": is_stable,
        }
