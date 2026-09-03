import os
import json
import hashlib
import time
import logging
from typing import Optional, Dict, Any
from pathlib import Path
from config import config as app_config

logger = logging.getLogger("veriframe.cache")

class ResultCache:
    def __init__(self, cache_dir: Optional[str] = None):
        self.cache_dir = cache_dir or app_config.CACHE_DIR
        os.makedirs(self.cache_dir, exist_ok=True)

    def _get_cache_path(self, video_hash: str) -> str:
        return os.path.join(self.cache_dir, f"{video_hash}.json")

    def get(self, video_hash: str) -> Optional[Dict[str, Any]]:
        if not app_config.CACHE_ENABLED:
            return None
        cache_path = self._get_cache_path(video_hash)
        if not os.path.exists(cache_path):
            return None
        try:
            with open(cache_path, "r") as f:
                cached = json.load(f)
            logger.info(f"[Cache] HIT for hash {video_hash[:16]}...")
            return cached
        except Exception as e:
            logger.warning(f"[Cache] Read error: {e}")
            return None

    def set(self, video_hash: str, result: Dict[str, Any]) -> bool:
        if not app_config.CACHE_ENABLED:
            return False
        try:
            cache_path = self._get_cache_path(video_hash)
            result["_cached_at"] = time.time()
            result["_video_hash"] = video_hash
            with open(cache_path, "w") as f:
                json.dump(result, f, indent=2, default=str)
            logger.info(f"[Cache] SET for hash {video_hash[:16]}...")
            return True
        except Exception as e:
            logger.warning(f"[Cache] Write error: {e}")
            return False

    def clear(self, video_hash: Optional[str] = None) -> bool:
        try:
            if video_hash:
                cache_path = self._get_cache_path(video_hash)
                if os.path.exists(cache_path):
                    os.remove(cache_path)
                return True
            for f in os.listdir(self.cache_dir):
                if f.endswith(".json"):
                    os.remove(os.path.join(self.cache_dir, f))
            return True
        except Exception as e:
            logger.warning(f"[Cache] Clear error: {e}")
            return False

    def stats(self) -> Dict[str, Any]:
        try:
            files = [f for f in os.listdir(self.cache_dir) if f.endswith(".json")]
            total_size = sum(os.path.getsize(os.path.join(self.cache_dir, f)) for f in files)
            return {
                "entries": len(files),
                "total_size_bytes": total_size,
                "cache_dir": self.cache_dir,
            }
        except Exception:
            return {"entries": 0, "total_size_bytes": 0, "cache_dir": self.cache_dir}