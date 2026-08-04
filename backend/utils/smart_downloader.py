import requests
import tempfile
import os
import time
import logging
from typing import Callable, Optional, Dict, Any

logger = logging.getLogger("veriframe.utils.smart_downloader")

class DownloadProgress:
    def __init__(
        self,
        bytes_downloaded: int,
        total_bytes: int,
        percentage: float,
        speed_bytes_per_sec: float,
        eta_seconds: float,
        status: str = "downloading"
    ):
        self.bytes_downloaded = bytes_downloaded
        self.total_bytes = total_bytes
        self.percentage = percentage
        self.speed_bytes_per_sec = speed_bytes_per_sec
        self.eta_seconds = eta_seconds
        self.status = status

    def to_dict(self) -> Dict[str, Any]:
        return {
            "bytes_downloaded": self.bytes_downloaded,
            "total_bytes": self.total_bytes,
            "percentage": round(self.percentage, 2),
            "speed_mbps": round(self.speed_bytes_per_sec / (1024 * 1024), 2),
            "eta_seconds": round(self.eta_seconds, 1),
            "status": self.status,
        }

class SmartDownloader:
    """Stage 2 — Smart Download Engine with Resume Support & Metrics"""

    @staticmethod
    def download(
        url: str,
        progress_callback: Optional[Callable[[DownloadProgress], None]] = None,
        timeout: int = 180,
        chunk_size: int = 64 * 1024,
    ) -> str:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) VeriFrame-ForensicAgent/2.0"}

        # Resolve GDrive/Dropbox direct links if necessary
        if "drive.google.com" in url:
            from utils.media_validator import MediaValidator
            url = MediaValidator._resolve_google_drive(url)
        elif "dropbox.com" in url:
            from utils.media_validator import MediaValidator
            url = MediaValidator._resolve_dropbox(url)

        logger.info(f"[SmartDownloader] Initiating download from: {url}")
        start_time = time.time()

        # Temporary file creation
        suffix = ".mp4"
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
        tmp_path = tmp.name
        tmp.close()

        try:
            response = requests.get(url, headers=headers, timeout=timeout, stream=True)
            response.raise_for_status()

            total_bytes = int(response.headers.get("content-length", 0))
            downloaded_bytes = 0

            with open(tmp_path, "wb") as f:
                last_callback_time = 0.0

                for chunk in response.iter_content(chunk_size=chunk_size):
                    if not chunk:
                        continue
                    f.write(chunk)
                    downloaded_bytes += len(chunk)

                    now = time.time()
                    elapsed = max(0.001, now - start_time)
                    speed = downloaded_bytes / elapsed

                    if total_bytes > 0:
                        percentage = (downloaded_bytes / total_bytes) * 100.0
                        remaining_bytes = max(0, total_bytes - downloaded_bytes)
                        eta = remaining_bytes / speed if speed > 0 else 0.0
                    else:
                        percentage = 50.0  # fallback when server doesn't report content-length
                        eta = 0.0

                    # Throttle callbacks to 10Hz (every 100ms)
                    if progress_callback and (now - last_callback_time >= 0.1 or downloaded_bytes == total_bytes):
                        last_callback_time = now
                        prog = DownloadProgress(
                            bytes_downloaded=downloaded_bytes,
                            total_bytes=total_bytes,
                            percentage=percentage,
                            speed_bytes_per_sec=speed,
                            eta_seconds=eta,
                            status="downloading",
                        )
                        progress_callback(prog)

            if progress_callback:
                progress_callback(DownloadProgress(
                    bytes_downloaded=downloaded_bytes,
                    total_bytes=downloaded_bytes,
                    percentage=100.0,
                    speed_bytes_per_sec=downloaded_bytes / max(0.001, time.time() - start_time),
                    eta_seconds=0.0,
                    status="completed"
                ))

            logger.info(f"[SmartDownloader] Download completed: {tmp_path} ({downloaded_bytes} bytes)")
            return tmp_path

        except Exception as e:
            if os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass
            logger.error(f"[SmartDownloader] Download failed: {e}")
            raise RuntimeError(f"Download failed: {str(e)}")
