import numpy as np
import logging
from typing import Dict, Any, List

logger = logging.getLogger("veriframe.calibration.evidence_fusion")

class EvidenceFusionEngine:
    """Stage 11, 12 & 13 — Calibration, Fusion & 5-Tier Decision Engine"""

    def __init__(self, temperature: float = 1.25, platt_a: float = 1.0, platt_b: float = 0.0):
        self.temperature = temperature
        self.platt_a = platt_a
        self.platt_b = platt_b

    def calibrate_confidence(self, raw_score: float) -> Dict[str, float]:
        """
        Stage 11 — Temperature + Platt Calibration
        Returns Real Probability, Fake Probability, Calibration Confidence, and Uncertainty.
        """
        # Clamp raw score
        eps = 1e-6
        p = np.clip(raw_score, eps, 1.0 - eps)

        # Logit transformation
        logit = np.log(p / (1.0 - p))

        # Temperature scaling
        temp_logit = logit / max(0.1, self.temperature)

        # Platt scaling
        platt_logit = self.platt_a * temp_logit + self.platt_b
        calibrated_p = 1.0 / (1.0 + np.exp(-platt_logit))

        real_prob = calibrated_p
        fake_prob = 1.0 - calibrated_p

        # Uncertainty calculation: normalized entropy
        entropy = - (real_prob * np.log2(real_prob + eps) + fake_prob * np.log2(fake_prob + eps))
        uncertainty = float(np.clip(entropy, 0.0, 1.0))

        # Confidence is distance from 0.5 boundary
        confidence = float(np.abs(real_prob - 0.5) * 2.0)

        return {
            "real_prob": round(float(real_prob), 4),
            "fake_prob": round(float(fake_prob), 4),
            "confidence": round(confidence * 100.0, 2),
            "uncertainty": round(uncertainty * 100.0, 2),
            "calibrated_score": round(float(calibrated_p), 4),
        }

    def fuse_evidence(
        self,
        calibrated_data: Dict[str, float],
        face_quality_score: float,
        metadata_anomaly_score: float,
        temporal_consistency_score: float,
        tracking_confidence: float,
        ocr_confidence: float,
        multi_crop_variance: float = 0.0,
    ) -> Dict[str, Any]:
        """
        Stage 12 — Evidence Fusion
        Combines model output with visual, spatial, and temporal indicators.
        """
        real_prob = calibrated_data["real_prob"]
        uncertainty = calibrated_data["uncertainty"]

        # Base evidence weight calculation
        w_ai = 0.55
        w_temporal = 0.15
        w_tracking = 0.15
        w_quality = 0.10
        w_metadata = 0.05

        # Quality penalty adjustment
        quality_factor = max(0.2, face_quality_score / 100.0)
        norm_temporal = max(0.0, temporal_consistency_score / 100.0)
        norm_tracking = max(0.0, tracking_confidence / 100.0)
        norm_meta_integrity = max(0.0, (100.0 - metadata_anomaly_score) / 100.0)

        fused_authenticity = (
            (real_prob * w_ai) +
            (norm_temporal * w_temporal) +
            (norm_tracking * w_tracking) +
            (quality_factor * w_quality) +
            (norm_meta_integrity * w_metadata)
        )

        fused_authenticity = float(np.clip(fused_authenticity * 100.0, 0.0, 100.0))
        fused_fake_prob = round(100.0 - fused_authenticity, 2)

        # Fused Confidence calculation
        fused_confidence = round(
            (calibrated_data["confidence"] * 0.6) +
            (norm_temporal * 20.0) +
            (norm_tracking * 20.0),
            2
        )

        # Stage 13 — 5-Tier Decision
        verdict = self.make_verdict(fused_authenticity, uncertainty)

        return {
            "authenticity_score": round(fused_authenticity, 2),
            "fake_probability": fused_fake_prob,
            "confidence": fused_confidence,
            "uncertainty": uncertainty,
            "verdict": verdict,
            "face_quality_score": round(face_quality_score, 2),
            "temporal_consistency_score": round(temporal_consistency_score, 2),
            "tracking_confidence": round(tracking_confidence, 2),
            "metadata_anomaly_score": round(metadata_anomaly_score, 2),
            "ocr_confidence": round(ocr_confidence, 2),
            "multi_crop_variance": round(multi_crop_variance, 4),
        }

    def make_verdict(self, authenticity_score: float, uncertainty: float) -> str:
        """
        Stage 13 — Decision Engine Output
        Possible 5-Tier Verdicts:
        - AUTHENTIC
        - LIKELY_AUTHENTIC
        - INCONCLUSIVE
        - LIKELY_MANIPULATED
        - MANIPULATED
        """
        if uncertainty > 80.0 or 42.0 <= authenticity_score <= 58.0:
            return "INCONCLUSIVE"
        elif authenticity_score >= 80.0:
            return "AUTHENTIC"
        elif authenticity_score >= 60.0:
            return "LIKELY_AUTHENTIC"
        elif authenticity_score >= 35.0:
            return "LIKELY_MANIPULATED"
        else:
            return "MANIPULATED"
