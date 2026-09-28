"""
Engine transparency for every verification response.

Clients previously had no way to tell a local-only verdict from an ensemble
verdict, or whether a Reality Defender number was fully settled. Every response
now carries an ``engine`` block with a fixed shape so the UI and any downstream
audit can rely on it:

    engine_used     "local" | "ensemble"
    rd_status       aggregate Reality Defender status, "" when not called
    rd_partial      True when the deadline hit with models still ANALYZING
    rd_request_id   Reality Defender request id, "" when not called
    model_version   fingerprint of the model files that produced the verdict
    thresholds      the exact cut-offs this response was thresholded with
"""

import hashlib
import os
import threading
import time
from typing import Any, Dict, Optional

from config import config as app_config

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The cut-offs each pipeline actually applies, extracted from the literals that
# used to be duplicated inside every pipeline. Pipelines import these so the
# numbers reported here are the numbers that were used, not a copy that can drift.
THRESHOLDS_IMAGE_AUDIO = {
    "manipulated_above_pct": 70.0,
    "authentic_below_pct": 30.0,
    "fake_confirmed_at_or_above_pct": 85.0,
    "real_confirmed_at_or_below_pct": 15.0,
}

THRESHOLDS_VIDEO = dict(THRESHOLDS_IMAGE_AUDIO)

THRESHOLDS_STREAM = {
    "manipulated_above_pct": 65.0,
    "authentic_below_pct": 35.0,
    "fake_confirmed_at_or_above_pct": 85.0,
    "real_confirmed_at_or_below_pct": 15.0,
}

THRESHOLDS_LINK = {
    "manipulated_above": 0.70,
    "inconclusive_range": [0.30, 0.70],
    "fake_confirmed_at_or_above": 0.80,
    "real_confirmed_at_or_below": 0.20,
    "note": "Link verdicts are thresholded on the 0-1 aggregated probability, not a percentage.",
}

THRESHOLDS_OFFLINE = dict(THRESHOLDS_IMAGE_AUDIO)

THRESHOLDS_BY_KIND: Dict[str, Dict[str, Any]] = {
    "image": THRESHOLDS_IMAGE_AUDIO,
    "audio": THRESHOLDS_IMAGE_AUDIO,
    "video": THRESHOLDS_VIDEO,
    "stream": THRESHOLDS_STREAM,
    "link": THRESHOLDS_LINK,
    "offline": THRESHOLDS_OFFLINE,
}

_LOCK = threading.Lock()
_MODEL_FINGERPRINTS: Dict[str, Dict[str, Any]] = {}


def _fingerprint(name: str) -> Dict[str, Any]:
    """Size + mtime + short sha256 for a model file, computed once per process."""
    with _LOCK:
        cached = _MODEL_FINGERPRINTS.get(name)
        if cached is not None:
            return cached

    path = os.path.join(_BASE_DIR, name)
    entry: Dict[str, Any] = {"file": name, "available": False}
    try:
        if os.path.exists(path):
            h = hashlib.sha256()
            with open(path, "rb") as f:
                while chunk := f.read(1 << 20):
                    h.update(chunk)
            entry = {
                "file": name,
                "available": True,
                "size_bytes": os.path.getsize(path),
                "modified_utc": time.strftime(
                    "%Y-%m-%dT%H:%M:%SZ", time.gmtime(os.path.getmtime(path))
                ),
                "sha256_16": h.hexdigest()[:16],
            }
    except OSError:
        pass

    with _LOCK:
        _MODEL_FINGERPRINTS[name] = entry
    return entry


def model_version() -> Dict[str, Any]:
    """Fingerprints of every model that can influence a verdict."""
    return {
        "api_version": "2.0.0",
        "models": [
            _fingerprint("veriframe_model.tflite"),
            _fingerprint("Image.tflite"),
            _fingerprint("Audio.tflite"),
        ],
    }


def thresholds_used(kind: str) -> Dict[str, Any]:
    """Verdict cut-offs plus the cloud-call budget they were produced under."""
    return {
        **THRESHOLDS_BY_KIND.get(kind, THRESHOLDS_IMAGE_AUDIO),
        "rd_timeout_sec": getattr(app_config, "REALITY_DEFENDER_TIMEOUT_SEC", 45),
        "rd_poll_interval_sec": getattr(app_config, "REALITY_DEFENDER_POLL_INTERVAL_SEC", 2.0),
        "rd_partial_confidence_factor": getattr(app_config, "RD_PARTIAL_CONFIDENCE_FACTOR", 0.5),
        "confidence_temperature": getattr(app_config, "CONFIDENCE_CALIBRATION_TEMP", 1.5),
    }


def engine_transparency(
    *,
    kind: str = "image",
    rd_result: Optional[Dict[str, Any]] = None,
    engine_used: Optional[str] = None,
) -> Dict[str, Any]:
    """Build the fixed-shape ``engine`` block.

    ``engine_used`` defaults to ``"ensemble"`` only when Reality Defender actually
    contributed a successful result; a partial result does not count as an
    ensemble input because its score is withheld from the blend.
    """
    rd_result = rd_result if isinstance(rd_result, dict) else None
    rd_ok = bool(rd_result) and rd_result.get("status") == "success"
    rd_partial = bool(rd_result.get("partial", False)) if rd_result else False

    if engine_used is None:
        engine_used = "ensemble" if (rd_ok and not rd_partial) else "local"

    return {
        "engine_used": engine_used,
        "rd_status": str(rd_result.get("rd_status") or "") if rd_result else "",
        "rd_partial": rd_partial,
        "rd_request_id": (rd_result.get("request_id") or "") if rd_result else "",
        "rd_incomplete_models": list(rd_result.get("incomplete_models") or []) if rd_result else [],
        "rd_contributed_to_score": bool(rd_ok and not rd_partial),
        "model_version": model_version(),
        "thresholds": thresholds_used(kind),
    }


def attach_engine_transparency(
    payload: Any,
    *,
    kind: str = "image",
    rd_result: Optional[Dict[str, Any]] = None,
    engine_used: Optional[str] = None,
) -> Any:
    """Attach the ``engine`` block to a response body, in place when possible."""
    block = engine_transparency(kind=kind, rd_result=rd_result, engine_used=engine_used)
    if isinstance(payload, dict):
        payload["engine"] = block
    elif isinstance(payload, list):
        for item in payload:
            if isinstance(item, dict):
                item["engine"] = block
    return payload
