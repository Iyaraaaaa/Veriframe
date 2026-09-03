import numpy as np
from typing import Optional
import logging

logger = logging.getLogger("veriframe.calibration")

class ConfidenceCalibrator:
    """
    Confidence Calibrator.
    Supports temperature scaling and Platt scaling (logistic regression on logits)
    to transform model output scores into calibrated probability estimates.
    """
    def __init__(self, temperature: float = 1.0, platt_a: float = 1.0, platt_b: float = 0.0):
        self.temperature = temperature
        self.platt_a = platt_a
        self.platt_b = platt_b

    def calibrate(self, raw_score: float) -> float:
        clipped = max(0.0, min(1.0, raw_score))
        if self.platt_a != 1.0 or self.platt_b != 0.0:
            eps = 1e-6
            p = max(eps, min(1.0 - eps, clipped))
            logit = np.log(p / (1.0 - p))
            calibrated = 1.0 / (1.0 + np.exp(-(self.platt_a * logit + self.platt_b)))
        else:
            calibrated = clipped ** (1.0 / max(self.temperature, 0.01))
        return float(np.clip(calibrated, 0.0, 1.0))

    def fit_temperature(self, scores: np.ndarray, labels: np.ndarray):
        scores = np.clip(scores, 1e-6, 1 - 1e-6)
        labels = labels.astype(np.float64)
        n = len(scores)
        if n == 0:
            return
        def loss(T):
            scaled = scores ** (1.0 / T)
            scaled = np.clip(scaled, 1e-6, 1 - 1e-6)
            return float(-np.mean(labels * np.log(scaled) + (1 - labels) * np.log(1 - scaled)))
        T = 1.0
        best_T = T
        best_loss = loss(T)
        for candidate_T in np.arange(0.5, 5.0, 0.1):
            current_loss = loss(candidate_T)
            if current_loss < best_loss:
                best_loss = current_loss
                best_T = candidate_T
        self.temperature = best_T
        logger.info(f"[Calibrator] Fitted temperature: {self.temperature:.4f}")

    def fit_platt(self, scores: np.ndarray, labels: np.ndarray):
        scores = np.clip(scores, 1e-6, 1 - 1e-6)
        log_scores = np.log(scores / (1.0 - scores))
        labels = labels.astype(np.float64)
        n = len(scores)
        if n < 2:
            return
        A = np.vstack([log_scores, np.ones(n)]).T
        try:
            sol, *_ = np.linalg.lstsq(A, labels, rcond=None)
            self.platt_a = float(sol[0])
            self.platt_b = float(sol[1])
            logger.info(f"[Calibrator] Fitted Platt: a={self.platt_a:.4f}, b={self.platt_b:.4f}")
        except Exception as e:
            logger.warning(f"[Calibrator] Platt fit failed: {e}")
