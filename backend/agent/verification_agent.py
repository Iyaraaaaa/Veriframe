import logging
from typing import Dict, Any, List

logger = logging.getLogger("veriframe.agent.verification_agent")

class VerificationAgent:
    """Central Adaptive Verification Agent Engine"""

    def __init__(self, confidence_stop_threshold: float = 95.0, min_stable_frames: int = 15):
        self.confidence_stop_threshold = confidence_stop_threshold
        self.min_stable_frames = min_stable_frames

    def decide_frame_budget(self, duration_sec: float, initial_quality: float) -> int:
        """Dynamically decides initial frame budget (20 to 60 frames)"""
        if duration_sec <= 5.0:
            return 20
        elif duration_sec <= 30.0:
            return 30
        elif duration_sec <= 120.0:
            return 45
        else:
            return 60

    def should_sample_more_frames(
        self,
        current_frame_count: int,
        max_limit: int,
        uncertainty: float,
        confidence: float
    ) -> bool:
        """Determines if additional evidence is needed based on uncertainty thresholds."""
        if current_frame_count >= max_limit:
            return False
        # Request extra frames if uncertainty is high (> 50%) or confidence is low (< 60%)
        if uncertainty > 50.0 or confidence < 60.0:
            logger.info(f"[VerificationAgent] Requesting additional frame extraction (Uncertainty: {uncertainty}%, Conf: {confidence}%)")
            return True
        return False

    def check_early_stopping(
        self,
        analyzed_frames: int,
        rolling_scores: List[float],
        current_confidence: float
    ) -> bool:
        """Decides when enough evidence has been collected to stop inference early."""
        if analyzed_frames < self.min_stable_frames:
            return False

        if current_confidence >= self.confidence_stop_threshold:
            # Check score stability in last min_stable_frames
            recent = rolling_scores[-self.min_stable_frames:]
            if max(recent) - min(recent) < 0.08:
                logger.info(f"[VerificationAgent] Early stopping triggered at frame {analyzed_frames} (High confidence: {current_confidence}%)")
                return True
        return False
