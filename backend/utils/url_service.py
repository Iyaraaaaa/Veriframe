import os
import requests
from urllib.parse import urlparse, parse_qs
from typing import Optional
import logging

logger = logging.getLogger("veriframe.url_service")

class URLService:
    SUPPORTED_DOMAINS = [
        "drive.google.com",
        "dropbox.com",
        "s3.amazonaws.com",
        "azure.blob.core.windows.net",
        "cloudinary.com",
    ]

    @staticmethod
    def is_video_url(url: str) -> bool:
        parsed = urlparse(url)
        path = parsed.path.lower()
        return any(path.endswith(ext) for ext in [".mp4", ".mov", ".avi", ".mkv", ".webm"]) or "video" in parsed.query

    @staticmethod
    def get_domain(url: str) -> str:
        return urlparse(url).netloc.lower()

    @classmethod
    def resolve_url(cls, url: str) -> str:
        domain = cls.get_domain(url)

        if "drive.google.com" in domain:
            return cls._resolve_google_drive(url)
        elif "dropbox.com" in domain:
            return cls._resolve_dropbox(url)
        elif "s3.amazonaws.com" in domain or "s3." in domain:
            return cls._resolve_s3(url)
        elif "azure.blob.core.windows.net" in domain:
            return cls._resolve_azure(url)
        elif "cloudinary.com" in domain:
            return cls._resolve_cloudinary(url)

        return url

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
            if "?" not in url:
                return f"{url}?dl=1"
        return url

    @staticmethod
    def _resolve_s3(url: str) -> str:
        return url

    @staticmethod
    def _resolve_azure(url: str) -> str:
        return url

    @staticmethod
    def _resolve_cloudinary(url: str) -> str:
        if "/upload/" in url and not url.endswith(".mp4"):
            return url.replace("/upload/", "/upload/fl_attachment/")
        return url

    @classmethod
    def download(cls, url: str, dest_path: str, timeout: int = 120) -> str:
        resolved = cls.resolve_url(url)
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

        response = requests.get(resolved, headers=headers, timeout=timeout, stream=True)
        response.raise_for_status()

        content_type = response.headers.get("content-type", "")
        suffix = ".mp4"
        if "video" in content_type or resolved.endswith(".mp4"):
            suffix = ".mp4"

        with open(dest_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)

        return dest_path