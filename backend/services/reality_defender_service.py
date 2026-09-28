import os
import logging
import asyncio
from typing import Dict, Any, Optional

from config import config as app_config
from detectors.reality_defender_detector import RealityDefenderDetector
from utils.score_utils import normalize_score_0_1

logger = logging.getLogger("veriframe.services.reality_defender_service")

class RealityDefenderService:
    """High‑level wrapper around :class:`RealityDefenderDetector`.

    Provides two convenience methods used by the verification pipelines:

    * ``analyze_media(file_path)`` – for whole video/image files.
    * ``analyze_bytes(data)`` – for a single frame (bytes) coming from a live stream.

    Both methods return a **normalized dict** that matches the ``VerificationResult``
    schema (except for UI‑only fields). Errors are captured and translated to a
    ``status`` field (``SUCCESS``, ``ERROR``, ``UNSUPPORTED``) together with a
    ``error_code`` identifier.
    """

    def __init__(self):
        self.detector = RealityDefenderDetector()
        if not self.detector.is_configured():
            logger.warning("RealityDefenderService initialized without a valid API key.")

    async def _detect_async(self, path: Optional[str] = None, data: Optional[bytes] = None) -> Dict[str, Any]:
        """Internal helper that delegates to the detector.

        Exactly one of ``path`` or ``data`` must be provided.
        """
        if path:
            return await self.detector.detect_file_async(path)
        if data:
            # The SDK currently only supports file paths, so we write a temporary file.
            import tempfile
            with tempfile.NamedTemporaryFile(delete=False, suffix=".tmp") as tmp:
                tmp.write(data)
                tmp_path = tmp.name
            try:
                result = await self.detector.detect_file_async(tmp_path)
            finally:
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass
            return result
        return {"status": "error", "error": "No input provided to RealityDefenderService"}

    def analyze_media(self, file_path: str) -> Dict[str, Any]:
        """Synchronous method for analysing a complete media file (video, image, audio).
        Returns the normalized dict.
        """
        try:
            raw = self.detector.detect_file(file_path)
        except Exception as e:
            logger.error(f"[RealityDefenderService] analyze_media error: {e}")
            raw = {"status": "error", "error": str(e)}
        return self._normalize(raw)

    async def analyze_media_async(self, file_path: str) -> Dict[str, Any]:
        """Asynchronous method for analysing a media file."""
        try:
            raw = await self.detector.detect_file_async(file_path)
        except Exception as e:
            logger.error(f"[RealityDefenderService] analyze_media_async error: {e}")
            raw = {"status": "error", "error": str(e)}
        return self._normalize(raw)

    def analyze_bytes(self, frame_bytes: bytes) -> Dict[str, Any]:
        """Analyse a single frame (bytes). Used by the live‑stream pipeline.
        """
        import tempfile
        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
                tmp.write(frame_bytes)
                tmp_path = tmp.name
            raw = self.detector.detect_file(tmp_path)
        except Exception as e:
            logger.error(f"[RealityDefenderService] analyze_bytes error: {e}")
            raw = {"status": "error", "error": str(e)}
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass
        return self._normalize(raw)

    def _normalize(self, raw: Dict[str, Any]) -> Dict[str, Any]:
        """Convert the raw detector response into the canonical dict used by the pipelines.

        A ``partial`` payload (the deadline was hit while at least one model was
        still ANALYZING) never yields a firm AUTHENTIC/MANIPULATED verdict: the
        verdict is downgraded to INCONCLUSIVE/UNCERTAIN and the confidence is
        scaled down, because the aggregate score was computed from a subset of
        the model panel.
        """
        status = raw.get("status")
        partial = bool(raw.get("partial", False))
        incomplete = list(raw.get("incomplete_models") or [])
        rd_status = str(raw.get("rd_status") or "")

        if status != "success":
            return {
                "status": status,
                "error_code": raw.get("error") or raw.get("reason") or "UNKNOWN",
                "error_message": raw.get("error") or raw.get("reason"),
                "fake_probability": 0.0,
                "authenticity_score": 100.0,
                "confidence": 0.0,
                "verdict": "UNKNOWN",
                "fine_verdict": "UNKNOWN",
                "request_id": raw.get("request_id"),
                "rd_status": rd_status,
                "partial": partial,
                "incomplete_models": incomplete,
                "models": [],
                "heatmaps": {},
                "evidence": [],
                "observations": [],
            }

        score = normalize_score_0_1(raw.get("score")) or 0.0
        fake_prob = round(score * 100.0, 2)
        auth_score = round(max(0.0, (1.0 - score) * 100.0), 2)

        models = raw.get("models", []) or []
        models = models if isinstance(models, list) else []

        if "MANIPULATED" in rd_status or fake_prob > 65.0:
            verdict = "MANIPULATED"
            fine_verdict = "FAKE" if fake_prob >= 85.0 else "LIKELY_FAKE"
        elif "AUTHENTIC" in rd_status or fake_prob < 35.0:
            verdict = "AUTHENTIC"
            fine_verdict = "REAL" if fake_prob <= 15.0 else "LIKELY_REAL"
        else:
            verdict = "INCONCLUSIVE"
            fine_verdict = "UNCERTAIN"

        evidence = []
        observations = []

        if raw.get("request_id"):
            observations.append(f"Reality Defender Request ID: {raw['request_id']}")
        if rd_status:
            observations.append(f"Reality Defender aggregate status: {rd_status}")

        _error_indicators = ("cannot read", "does not support", "not support", "error", "failed", "inform the user")
        in_progress_indicators = ("analyzing", "downloading", "pending", "in_progress", "queued")

        for m in models:
            if not isinstance(m, dict):
                continue
            m_name = m.get("name", "Model")
            m_status = m.get("status", "")
            m_status_text = str(m_status).upper()
            # Per-model predictionNumber is 0-100 for most models but a 0-1
            # fraction for others (e.g. rd-context-img). Normalize before use.
            m_score = normalize_score_0_1(m.get("score"))
            m_score_pct = None if m_score is None else round(m_score * 100.0, 2)
            score_str = f" ({m_score_pct}%)" if m_score_pct is not None else ""

            if any(ind in str(m_status).lower() for ind in in_progress_indicators):
                observations.append(f"Reality Defender {m_name}: {m_status or 'PENDING'} (no score yet)")
                continue
            if any(ind in str(m_status).lower() for ind in _error_indicators):
                continue
            if m_score is None:
                continue
            if "MANIPULATED" in m_status_text or m_score_pct > 60.0:
                evidence.append(f"Reality Defender {m_name}: Flagged as {m_status}{score_str}")
            else:
                observations.append(f"Reality Defender {m_name}: {m_status}{score_str}")

        if partial:
            verdict = "INCONCLUSIVE"
            fine_verdict = "UNCERTAIN"
            evidence = []
            missing = ", ".join(incomplete) if incomplete else "unknown"
            observations.append(
                f"PARTIAL Reality Defender result: {len(incomplete)} model(s) still ANALYZING when the "
                f"deadline was reached ({missing}). The aggregate score is based on an incomplete model "
                "panel, so it is reported for traceability only and no AUTHENTIC/MANIPULATED verdict is derived."
            )

        confidence = float(raw.get("confidence", 85.0))
        if partial:
            confidence *= float(getattr(app_config, "RD_PARTIAL_CONFIDENCE_FACTOR", 0.5))
        confidence = round(min(100.0, max(0.0, confidence)), 2)

        return {
            "status": "success",
            "request_id": raw.get("request_id"),
            "fake_probability": fake_prob,
            "authenticity_score": auth_score,
            "confidence": confidence,
            "verdict": verdict,
            "fine_verdict": fine_verdict,
            "rd_status": rd_status,
            "partial": partial,
            "incomplete_models": incomplete,
            "models": models,
            "heatmaps": raw.get("heatmaps", {}),
            "evidence": evidence,
            "observations": observations,
        }
