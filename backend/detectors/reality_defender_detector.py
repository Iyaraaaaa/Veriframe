import os
import time
import logging
import asyncio
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError
from typing import Dict, Any, Optional
from config import config as app_config
from utils.score_utils import normalize_score_0_1

logger = logging.getLogger("veriframe.detectors.reality_defender")

# Dedicated single-worker pool. A hung SDK call cannot be cancelled, so it is
# isolated here: the caller gets a timeout response while the stuck call is
# abandoned on its own thread instead of blocking the request forever.
_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="rd-sdk")

# Statuses that mean "this model has not produced a score yet". The top-level
# status can already be final (AUTHENTIC/MANIPULATED) while individual models
# are still running, so both levels have to be checked.
_IN_PROGRESS_STATUSES = frozenset({"ANALYZING", "DOWNLOADING", "PENDING", "IN_PROGRESS", "QUEUED"})


def models_still_analyzing(models: Any) -> list:
    """Names of models that have not finished yet, in the order the API listed them."""
    if not isinstance(models, list):
        return []
    pending = []
    for m in models:
        if not isinstance(m, dict):
            continue
        if str(m.get("status", "")).upper() in _IN_PROGRESS_STATUSES:
            pending.append(m.get("name", "unknown"))
    return pending

class RealityDefenderDetector:
    """
    Detector service that integrates Reality Defender API / SDK for media forensics and deepfake detection.
    """

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or app_config.REALITY_DEFENDER_API_KEY or os.getenv("REALITY_DEFENDER_API_KEY", "")
        self._sdk_client = None

    def is_configured(self) -> bool:
        """Check if an API key is provided and not masked with ellipsis."""
        if not self.api_key:
            return False
        if "..." in self.api_key:
            logger.warning("[RealityDefenderDetector] API key appears masked (contains '...'). Please configure the full unmasked key.")
            return False
        return True

    def _get_sdk_client(self):
        if not self.is_configured():
            return None
        if self._sdk_client is None:
            try:
                from realitydefender import RealityDefender
                self._sdk_client = RealityDefender(api_key=self.api_key)
            except ImportError:
                logger.warning("[RealityDefenderDetector] 'realitydefender' package not installed. Run `pip install realitydefender`.")
                return None
            except Exception as e:
                logger.error(f"[RealityDefenderDetector] Failed to initialize Reality Defender SDK: {e}")
                return None
        return self._sdk_client

    def _describe_error(self, e: Exception) -> str:
        """
        Best-effort extraction of HTTP status and response body from an SDK exception.
        The realitydefender SDK wraps different HTTP clients, so we probe common shapes.
        """
        parts = [f"{type(e).__name__}: {e}"]

        status = None
        for attr in ("status_code", "status"):
            value = getattr(e, attr, None)
            if isinstance(value, int):
                status = value
                break
        if status is None:
            resp = getattr(e, "response", None)
            if resp is not None:
                status = getattr(resp, "status_code", None)
        if status is not None:
            parts.append(f"http_status={status}")

        body = None
        for source in (getattr(e, "response", None), e):
            if source is None:
                continue
            for attr in ("text", "body", "content"):
                value = getattr(source, attr, None)
                if isinstance(value, (str, bytes)) and value:
                    body = value if isinstance(value, str) else value.decode("utf-8", "replace")
                    break
            if body:
                break
        if body:
            body = body.strip().replace("\n", " ")[:1000]
            parts.append(f"response_body={body}")
        else:
            parts.append("response_body=<unavailable on this exception type>")

        return " | ".join(parts)

    def _call_sdk(self, fn, *args, timeout: float, **kwargs):
        """Run a blocking SDK call on the isolated pool, bounded by ``timeout`` seconds."""
        future = _executor.submit(fn, *args, **kwargs)
        try:
            return future.result(timeout=timeout)
        except FutureTimeoutError:
            future.cancel()
            raise

    def _upload(self, client, file_path: str, deadline: float) -> str:
        """Upload the media and return its request_id, bounded by the shared deadline."""
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise FutureTimeoutError("deadline exceeded before upload")
        logger.info("[RealityDefenderDetector] POST upload -> %s (%.1fs left)", file_path, remaining)
        upload_result = self._call_sdk(client.upload_sync, file_path=file_path, timeout=remaining)
        request_id = (upload_result or {}).get("request_id", "")
        logger.info("[RealityDefenderDetector] upload accepted request_id=%s", request_id or "<none>")
        if not request_id:
            raise ValueError("Reality Defender upload returned no request_id")
        return request_id

    def _fetch_result(self, client, request_id: str, timeout: float) -> Dict[str, Any]:
        """One result fetch. ``max_attempts=1`` keeps the SDK from sleeping on our behalf."""
        return self._call_sdk(
            client.get_result_sync, request_id, max_attempts=1, timeout=max(1.0, timeout)
        ) or {}

    def _poll_until_settled(self, client, request_id: str, deadline: float) -> tuple:
        """Poll until the scan **and every model** has finished, or the deadline passes.

        Returns ``(result, partial, incomplete_models)``. ``partial`` is True when the
        deadline hit while at least one model was still ANALYZING; in that case the
        top-level score is not trustworthy and the caller must not present a firm verdict.
        """
        interval = max(0.5, float(getattr(app_config, "REALITY_DEFENDER_POLL_INTERVAL_SEC", 2.0)))
        polls = 0
        result: Dict[str, Any] = {}
        incomplete: list = []
        timed_out = False

        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0 and polls > 0:
                timed_out = True
                break
            polls += 1
            try:
                result = self._fetch_result(client, request_id, timeout=max(1.0, remaining))
            except FutureTimeoutError:
                logger.error(
                    "[RealityDefenderDetector] result fetch timed out for request_id=%s", request_id
                )
                timed_out = True
                break

            incomplete = models_still_analyzing(result.get("models"))
            top_in_progress = str(result.get("status", "")).upper() in _IN_PROGRESS_STATUSES
            logger.info(
                "[RealityDefenderDetector] poll #%d request_id=%s rd_status=%s score=%s "
                "incomplete_models=%d",
                polls, request_id, result.get("status"), result.get("score"), len(incomplete),
            )

            if not incomplete and not top_in_progress:
                return result, False, []

            remaining = deadline - time.monotonic()
            if remaining <= 0:
                timed_out = True
                break
            time.sleep(min(interval, remaining))

        logger.warning(
            "[RealityDefenderDetector] DEADLINE reached request_id=%s incomplete_models=%s",
            request_id, incomplete or "<none>",
        )
        return result, timed_out and bool(incomplete), incomplete

    def detect_file(self, file_path: str) -> Dict[str, Any]:
        """
        Synchronously sends a media file (image/video/audio) to Reality Defender for deepfake detection.

        The top-level status is only treated as final once **no model** is still
        ANALYZING. If the deadline is reached first the result is flagged
        ``partial`` and no firm verdict is derived from it.
        """
        if not os.path.exists(file_path):
            return {
                "status": "error",
                "error": f"File not found: {file_path}",
                "is_fake": False,
                "score": 0.0,
                "confidence": 0.0,
            }

        if not self.is_configured():
            logger.warning("[RealityDefenderDetector] Call skipped: API key not configured or masked.")
            return {
                "status": "skipped",
                "reason": "Reality Defender API key is not configured or is masked.",
                "is_fake": False,
                "score": 0.0,
                "confidence": 0.0,
            }

        client = self._get_sdk_client()
        if not client:
            logger.warning("[RealityDefenderDetector] Call skipped: SDK client unavailable.")
            return {
                "status": "skipped",
                "reason": "Reality Defender SDK unavailable.",
                "is_fake": False,
                "score": 0.0,
                "confidence": 0.0,
            }

        timeout = float(getattr(app_config, "REALITY_DEFENDER_TIMEOUT_SEC", 45))
        poll_interval = float(getattr(app_config, "REALITY_DEFENDER_POLL_INTERVAL_SEC", 2.0))
        partial_factor = float(getattr(app_config, "RD_PARTIAL_CONFIDENCE_FACTOR", 0.5))
        deadline = time.monotonic() + timeout
        started = time.monotonic()

        try:
            request_id = self._upload(client, file_path, deadline)
            result, partial, incomplete = self._poll_until_settled(client, request_id, deadline)
        except FutureTimeoutError:
            logger.error(
                "[RealityDefenderDetector] FAILED -> timed out after %ss | "
                "http_status=<none> | response_body=<no response; SDK did not return in time>",
                timeout,
            )
            return {
                "status": "error",
                "error": f"Reality Defender timed out after {timeout}s",
                "is_fake": False,
                "score": 0.0,
                "confidence": 0.0,
                "partial": False,
            }
        except Exception as e:
            logger.error(f"[RealityDefenderDetector] FAILED -> {self._describe_error(e)}")
            return {
                "status": "error",
                "error": str(e),
                "is_fake": False,
                "score": 0.0,
                "confidence": 0.0,
                "partial": False,
            }

        raw_status = str(result.get("status", "")).upper()
        # Top-level finalScore is 0-100 per the API and is already divided by 100
        # by the SDK; normalize_score_0_1 keeps it correct either way.
        norm_score = normalize_score_0_1(result.get("score")) or 0.0
        models = result.get("models", []) or []
        models = models if isinstance(models, list) else []

        if partial:
            logger.warning(
                "[RealityDefenderDetector] PARTIAL result request_id=%s incomplete=%s score=%.4f "
                "(confidence and verdict suppressed)",
                result.get("request_id", request_id), incomplete, norm_score,
            )
        else:
            logger.info(
                "[RealityDefenderDetector] SUCCESS request_id=%s rd_status=%s score=%.4f models=%d",
                result.get("request_id", request_id), raw_status or "<empty>",
                norm_score, len(models),
            )
        for m in models:
            if not isinstance(m, dict):
                continue
            logger.info(
                "[RealityDefenderDetector]   model=%s status=%s raw_score=%s normalized=%s",
                m.get("name", "?"), m.get("status", "?"), m.get("score"),
                normalize_score_0_1(m.get("score")),
            )

        is_fake = False if partial else (
            "MANIPULATED" in raw_status or "SYNTHETIC" in raw_status or norm_score >= 0.50
        )
        confidence = round(abs(norm_score - 0.5) * 200, 2)
        if partial:
            confidence = round(confidence * partial_factor, 2)

        return {
            "status": "success",
            "request_id": result.get("request_id", request_id),
            "score": norm_score,
            "percentage_score": round(norm_score * 100.0, 2),
            "is_fake": is_fake,
            "confidence": confidence,
            "rd_status": raw_status,
            "partial": partial,
            "incomplete_models": incomplete,
            "timed_out": partial,
            "polling_interval_sec": poll_interval,
            "elapsed_sec": round(time.monotonic() - started, 2),
            "models": models,
            "heatmaps": result.get("heatmaps") or {},
            "details": dict(result),
        }

    async def detect_file_async(self, file_path: str) -> Dict[str, Any]:
        """Asynchronous wrapper that runs synchronous detection in a background executor."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.detect_file, file_path)
