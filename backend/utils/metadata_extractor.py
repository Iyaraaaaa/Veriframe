import cv2
import os
import subprocess
import json
import logging
from typing import Dict, Any

logger = logging.getLogger("veriframe.utils.metadata_extractor")

class VideoMetadata:
    def __init__(
        self,
        codec: str = "unknown",
        fps: float = 0.0,
        duration_sec: float = 0.0,
        bitrate_kbps: float = 0.0,
        width: int = 0,
        height: int = 0,
        rotation: int = 0,
        creation_time: str = "Unknown",
        editing_software: str = "None detected",
        metadata_anomaly_score: float = 0.0,
        raw_metadata: Dict[str, Any] = None,
    ):
        self.codec = codec
        self.fps = fps
        self.duration_sec = duration_sec
        self.bitrate_kbps = bitrate_kbps
        self.width = width
        self.height = height
        self.rotation = rotation
        self.creation_time = creation_time
        self.editing_software = editing_software
        self.metadata_anomaly_score = metadata_anomaly_score
        self.raw_metadata = raw_metadata or {}

    def to_dict(self) -> Dict[str, Any]:
        return {
            "codec": self.codec,
            "fps": round(self.fps, 2),
            "duration_sec": round(self.duration_sec, 2),
            "bitrate_kbps": round(self.bitrate_kbps, 1),
            "resolution": f"{self.width}x{self.height}",
            "width": self.width,
            "height": self.height,
            "rotation": self.rotation,
            "creation_time": self.creation_time,
            "editing_software": self.editing_software,
            "metadata_anomaly_score": round(self.metadata_anomaly_score, 2),
        }

class MetadataExtractor:
    """Stage 3 — Metadata Analysis Engine"""

    @staticmethod
    def extract(video_path: str) -> VideoMetadata:
        if not os.path.exists(video_path):
            return VideoMetadata()

        # Try FFprobe for deep metadata inspection if available
        ffprobe_data = MetadataExtractor._run_ffprobe(video_path)

        cap = cv2.VideoCapture(video_path)
        w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        fps = float(cap.get(cv2.CAP_PROP_FPS))
        count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        duration = count / fps if fps > 0 else 0.0
        cap.release()

        file_size_bytes = os.path.getsize(video_path)
        bitrate_kbps = (file_size_bytes * 8 / 1024) / duration if duration > 0 else 0.0

        codec = "h264"
        rotation = 0
        creation_time = "Unknown"
        editing_software = "None detected"

        if ffprobe_data and "streams" in ffprobe_data:
            for s in ffprobe_data["streams"]:
                if s.get("codec_type") == "video":
                    codec = s.get("codec_name", codec)
                    if "tags" in s:
                        tags = s["tags"]
                        creation_time = tags.get("creation_time", creation_time)
                        if "rotate" in tags:
                            try:
                                rotation = int(tags["rotate"])
                            except ValueError:
                                pass
            if "format" in ffprobe_data and "tags" in ffprobe_data["format"]:
                ftags = ffprobe_data["format"]["tags"]
                if "encoder" in ftags:
                    editing_software = ftags["encoder"]
                elif "software" in ftags:
                    editing_software = ftags["software"]
                elif "handler_name" in ftags:
                    editing_software = ftags["handler_name"]

        # Compute metadata anomaly score (0-100)
        anomaly_score = 0.0
        known_editing = ["Adobe Premiere", "After Effects", "CapCut", "FFmpeg", "HandBrake", "DeepFaceLab", "FaceSwap", "Nuke", "Blender"]
        for sw in known_editing:
            if sw.lower() in editing_software.lower():
                anomaly_score += 35.0
                break

        if fps < 10 or fps > 120:
            anomaly_score += 25.0
        if w < 128 or h < 128:
            anomaly_score += 20.0
        if bitrate_kbps < 100:
            anomaly_score += 20.0

        anomaly_score = min(100.0, anomaly_score)

        return VideoMetadata(
            codec=codec,
            fps=fps,
            duration_sec=duration,
            bitrate_kbps=bitrate_kbps,
            width=w,
            height=h,
            rotation=rotation,
            creation_time=creation_time,
            editing_software=editing_software,
            metadata_anomaly_score=anomaly_score,
            raw_metadata=ffprobe_data or {},
        )

    @staticmethod
    def _run_ffprobe(video_path: str) -> Dict[str, Any]:
        try:
            cmd = [
                "ffprobe",
                "-v", "quiet",
                "-print_format", "json",
                "-show_format",
                "-show_streams",
                video_path,
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                return json.loads(res.stdout)
        except Exception:
            pass
        return {}
