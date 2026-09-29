import cv2
import numpy as np
import base64
from typing import List, Tuple, Optional

def get_video_metadata(video_path: str) -> dict:
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return {}
    metadata = {
        "width": int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
        "height": int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        "fps": float(cap.get(cv2.CAP_PROP_FPS)),
        "frame_count": int(cap.get(cv2.CAP_PROP_FRAME_COUNT)),
        "duration_sec": 0.0,
    }
    cap.release()
    if metadata["fps"] > 0:
        metadata["duration_sec"] = metadata["frame_count"] / metadata["fps"]
    return metadata


def extract_video_thumbnail_base64(video_path: str, max_size: int = 320) -> Optional[str]:
    """
    Extract a thumbnail from the video at 10% duration (or first frame if very short)
    and return as base64 encoded JPEG string.
    """
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return None

    try:
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        if frame_count <= 0:
            return None

        # Extract frame at ~10% of video duration, or first frame if very short
        target_frame = max(0, min(frame_count // 10, frame_count - 1))
        cap.set(cv2.CAP_PROP_POS_FRAMES, target_frame)
        ret, frame = cap.read()
        if not ret or frame is None:
            # Fallback to first frame
            cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            ret, frame = cap.read()
            if not ret or frame is None:
                return None

        # Resize to max_size maintaining aspect ratio
        h, w = frame.shape[:2]
        if max(h, w) > max_size:
            scale = max_size / max(h, w)
            new_w = int(w * scale)
            new_h = int(h * scale)
            frame = cv2.resize(frame, (new_w, new_h), interpolation=cv2.INTER_AREA)

        # Encode to JPEG
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        return base64.b64encode(buffer).decode('utf-8')
    except Exception:
        return None
    finally:
        cap.release()


def decode_base64_frame(base64_data: str) -> Optional[np.ndarray]:
    import base64
    try:
        if "," in base64_data:
            base64_data = base64_data.split(",", 1)[1]
        img_bytes = base64.b64decode(base64_data)
        nparr = np.frombuffer(img_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        return frame
    except Exception:
        return None

def compute_frame_diff_hist(frame1: np.ndarray, frame2: np.ndarray) -> float:
    hist1 = cv2.calcHist([frame1], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
    hist2 = cv2.calcHist([frame2], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
    cv2.normalize(hist1, hist1)
    cv2.normalize(hist2, hist2)
    corr = cv2.compareHist(hist1, hist2, cv2.HISTCMP_CORREL)
    return float(corr)

def compute_optical_flow_magnitude(frame1: np.ndarray, frame2: np.ndarray) -> float:
    # Downscale for memory-safe and efficient optical flow computation
    h, w = frame1.shape[:2]
    if max(h, w) > 256:
        scale = 256.0 / max(h, w)
        frame1 = cv2.resize(frame1, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
        frame2 = cv2.resize(frame2, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    gray1 = cv2.cvtColor(frame1, cv2.COLOR_BGR2GRAY)
    gray2 = cv2.cvtColor(frame2, cv2.COLOR_BGR2GRAY)
    flow = cv2.calcOpticalFlowFarneback(gray1, gray2, None, 0.5, 3, 15, 3, 5, 1.2, 0)
    magnitude = np.sqrt(flow[..., 0]**2 + flow[..., 1]**2)
    return float(np.mean(magnitude))

