import urllib.parse
import requests
import cv2
import os
import logging
from typing import Dict, Any, Tuple

logger = logging.getLogger("veriframe.utils.media_validator")

SUPPORTED_SCHEMES = ("http", "https")
SUPPORTED_EXTENSIONS = (".mp4", ".mov", ".avi", ".mkv", ".webm", ".flv", ".m4v")
SUPPORTED_DOMAINS = ("drive.google.com", "dropbox.com", "youtube.com", "youtu.be", "vimeo.com")

class MediaValidationResult:
    def __init__(
        self,
        is_valid: bool,
        error_message: str = "",
        mime_type: str = "video/mp4",
        estimated_size_bytes: int = 0,
        direct_url: str = "",
        platform: str = "Direct HTTP/HTTPS",
        headers_info: Dict[str, Any] = None,
    ):
        self.is_valid = is_valid
        self.error_message = error_message
        self.mime_type = mime_type
        self.estimated_size_bytes = estimated_size_bytes
        self.direct_url = direct_url
        self.platform = platform
        self.headers_info = headers_info or {}

    def to_dict(self) -> Dict[str, Any]:
        return {
            "is_valid": self.is_valid,
            "error_message": self.error_message,
            "mime_type": self.mime_type,
            "estimated_size_bytes": self.estimated_size_bytes,
            "direct_url": self.direct_url,
            "platform": self.platform,
        }

class MediaValidator:
    """Stage 1 — Validate Media Pre-flight Checks"""

    @staticmethod
    def validate_url(url: str, timeout: int = 10) -> MediaValidationResult:
        if not url or not isinstance(url, str):
            return MediaValidationResult(False, "Empty or invalid URL string provided.")

        clean_url = url.strip()
        parsed = urllib.parse.urlparse(clean_url)

        if parsed.scheme.lower() not in SUPPORTED_SCHEMES:
            return MediaValidationResult(False, f"Unsupported URL scheme '{parsed.scheme}'. Must be HTTP/HTTPS.")

        domain = parsed.netloc.lower()
        platform = "Direct HTTP/HTTPS"
        direct_url = clean_url

        if "drive.google.com" in domain:
            platform = "Google Drive"
            direct_url = MediaValidator._resolve_google_drive(clean_url)
        elif "dropbox.com" in domain:
            platform = "Dropbox"
            direct_url = MediaValidator._resolve_dropbox(clean_url)
        elif "youtube.com" in domain or "youtu.be" in domain:
            platform = "YouTube"
        elif "vimeo.com" in domain:
            platform = "Vimeo"

        # Pre-flight HTTP HEAD / GET probe
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) VeriFrame-ForensicAgent/2.0"}
        try:
            head_resp = requests.head(direct_url, headers=headers, timeout=timeout, allow_redirects=True)
            status_code = head_resp.status_code

            if status_code >= 400:
                # Fallback to GET stream probe for servers that reject HEAD requests
                get_resp = requests.get(direct_url, headers=headers, timeout=timeout, stream=True)
                if get_resp.status_code >= 400:
                    return MediaValidationResult(False, f"Media server returned HTTP error status {get_resp.status_code}.")
                content_type = get_resp.headers.get("content-type", "").lower()
                content_length = int(get_resp.headers.get("content-length", 0))
                get_resp.close()
            else:
                content_type = head_resp.headers.get("content-type", "").lower()
                content_length = int(head_resp.headers.get("content-length", 0))

            # Validate MIME type or URL extension
            has_video_mime = "video" in content_type or "octet-stream" in content_type or "binary" in content_type
            has_video_ext = any(parsed.path.lower().endswith(ext) for ext in SUPPORTED_EXTENSIONS)

            if not has_video_mime and not has_video_ext and platform == "Direct HTTP/HTTPS":
                logger.warning(f"[MediaValidator] Unrecognized MIME type '{content_type}' for URL {clean_url}")

            # Enforce max size limit (e.g., 500 MB max)
            max_bytes = 500 * 1024 * 1024
            if content_length > max_bytes:
                return MediaValidationResult(False, f"Media file size ({content_length / 1024 / 1024:.1f} MB) exceeds limit of 500 MB.")

            return MediaValidationResult(
                is_valid=True,
                mime_type=content_type or "video/mp4",
                estimated_size_bytes=content_length,
                direct_url=direct_url,
                platform=platform,
            )

        except requests.exceptions.RequestException as e:
            logger.error(f"[MediaValidator] Validation failed for {clean_url}: {e}")
            return MediaValidationResult(False, f"Network error during media validation: {str(e)}")

    @staticmethod
    def validate_file_integrity(file_path: str) -> Tuple[bool, str]:
        """Verify video file header integrity using OpenCV VideoCapture"""
        if not os.path.exists(file_path):
            return False, "File does not exist on disk."
        if os.path.getsize(file_path) == 0:
            return False, "Downloaded video file is empty (0 bytes)."

        cap = cv2.VideoCapture(file_path)
        if not cap.isOpened():
            cap.release()
            return False, "Failed to open video container. Corrupted or unsupported video codec."

        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        cap.release()

        if frame_count <= 0 or width <= 0 or height <= 0:
            return False, f"Invalid video geometry or frame count (Frames: {frame_count}, Resolution: {width}x{height})."

        return True, "Video file integrity verified."

    @staticmethod
    def _resolve_google_drive(url: str) -> str:
        if "/file/d/" in url:
            file_id = url.split("/file/d/")[1].split("/")[0]
            return f"https://drive.google.com/uc?export=download&id={file_id}"
        return url

    @staticmethod
    def _resolve_dropbox(url: str) -> str:
        if "dropbox.com" in url:
            if "dl=0" in url:
                return url.replace("dl=0", "dl=1")
            elif "dl=1" not in url:
                return url + ("&dl=1" if "?" in url else "?dl=1")
        return url
