from fastapi import FastAPI, File, UploadFile, BackgroundTasks, HTTPException, Form
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import tensorflow as tf
import numpy as np
import cv2
import tempfile
import os
import hashlib
import time
import base64
import logging
import io
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed, TimeoutError as FuturesTimeoutError
from typing import Dict, Any, Optional
import requests
import re
from starlette.concurrency import run_in_threadpool

from config import config as app_config
from utils.logger import setup_logger
from detectors.face_detector import FaceDetector, FaceDetectionResult
from filters.frame_sampler import AdaptiveFrameSampler
from filters.quality_filter import QualityFilter, FaceQualityConfig
from calibration.temporal_filter import TemporalFilter
from calibration.confidence_calibration import ConfidenceCalibrator
from pipelines.video_pipeline import VideoPipeline
from pipelines.link_pipeline import LinkPipeline
from pipelines.link_verification_v2 import LinkVerificationV2
from pipelines.stream_pipeline import StreamPipeline
from pipelines.offline_pipeline import OfflinePipeline
from pipelines.image_pipeline import ImagePipeline
from pipelines.audio_pipeline import AudioPipeline
from services.reality_defender_service import RealityDefenderService
from services.gemini_service import GeminiService
from preprocessing.preprocessor import FramePreprocessor
from cache.result_cache import ResultCache
from database.connection import init_db, upsert_job, insert_report, insert_history, get_report_by_hash, list_reports
from database.models import JobRecord, ReportRecord, CacheEntry, AnalysisHistory
from utils.video import get_video_metadata, decode_base64_frame
from utils.image import compute_face_quality_score, pad_to_square
from utils.transparency import attach_engine_transparency, engine_transparency

logger = setup_logger()
app = FastAPI(title="Veriframe API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Load model once at startup, with fallback path ----
model_path = None
for candidate in app_config.MODEL_FALLBACK_PATHS:
    if os.path.exists(candidate):
        model_path = candidate
        break

if model_path is None:
    model_path = "veriframe_model.tflite"

try:
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    logger.info(f"[Main] Video model loaded: {model_path}")
except Exception as e:
    logger.error(f"[Main] Model load failed: {e}")
    raise RuntimeError(f"Failed to load TFLite model: {e}")

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# ---- Load dedicated Image.tflite (input [1,224,224,3] → output [1,2] softmax [real,fake]) ----
_image_model_path = os.path.join(_BASE_DIR, "Image.tflite")
try:
    img_interpreter = tf.lite.Interpreter(model_path=_image_model_path)
    img_interpreter.allocate_tensors()
    img_input_details = img_interpreter.get_input_details()
    img_output_details = img_interpreter.get_output_details()
    image_model_name = "image"
    logger.info(f"[Main] Image.tflite loaded: {_image_model_path}")
except Exception as _img_err:
    logger.warning(f"[Main] Image.tflite not loaded ({_img_err}), falling back to video model.")
    img_interpreter = interpreter
    img_input_details = input_details
    img_output_details = output_details
    image_model_name = "video-model fallback"

# ---- Load dedicated Audio.tflite (input [1,1536] spectral projection -> output [1,1] sigmoid) ----
_audio_model_path = os.path.join(_BASE_DIR, "Audio.tflite")
try:
    aud_interpreter = tf.lite.Interpreter(model_path=_audio_model_path)
    aud_interpreter.allocate_tensors()
    aud_input_details = aud_interpreter.get_input_details()
    aud_output_details = aud_interpreter.get_output_details()
    logger.info(f"[Main] Audio.tflite loaded: {_audio_model_path}")
except Exception as _aud_err:
    logger.warning(f"[Main] Audio.tflite not loaded ({_aud_err}), skipping on-device audio TFLite.")
    aud_interpreter = None
    aud_input_details = None
    aud_output_details = None


INPUT_SIZE = app_config.INPUT_SIZE
preprocessor = FramePreprocessor(target_size=INPUT_SIZE)
cache = ResultCache()

# Initialize database
init_db()

# ---- Initialize modular pipeline components ----
face_detector = FaceDetector(input_size=INPUT_SIZE)
frame_sampler = AdaptiveFrameSampler(target_frames=app_config.TARGET_FRAMES, max_frames=app_config.MAX_FRAMES)
quality_filter = QualityFilter(config=FaceQualityConfig(
    blur_variance_threshold=app_config.BLUR_VAR_THRESHOLD,
    brightness_min=app_config.BRIGHTNESS_MIN,
    brightness_max=app_config.BRIGHTNESS_MAX,
    face_size_ratio_min=app_config.FACE_SIZE_RATIO_MIN,
    face_size_ratio_max=app_config.FACE_SIZE_RATIO_MAX,
    min_face_size=app_config.MIN_FACE_SIZE,
))
temporal_filter = TemporalFilter(window_size=app_config.TEMPORAL_WINDOW_SIZE)
calibrator = ConfidenceCalibrator(temperature=app_config.CONFIDENCE_CALIBRATION_TEMP)

rd_service = RealityDefenderService()
gemini_service = GeminiService()

video_pipeline = VideoPipeline(
    interpreter=interpreter,
    input_details=input_details,
    output_details=output_details,
    face_detector=face_detector,
    frame_sampler=frame_sampler,
    quality_filter=quality_filter,
    temporal_filter=temporal_filter,
    calibrator=calibrator,
    preprocessor=preprocessor,
    rd_service=rd_service,
)

link_pipeline = LinkPipeline(
    interpreter=interpreter,
    input_details=input_details,
    output_details=output_details,
    face_detector=face_detector,
    frame_sampler=frame_sampler,
    quality_filter=quality_filter,
    temporal_filter=TemporalFilter(window_size=app_config.TEMPORAL_WINDOW_SIZE),
    calibrator=calibrator,
    preprocessor=preprocessor,
)

image_pipeline = ImagePipeline(
    interpreter=img_interpreter,
    input_details=img_input_details,
    output_details=img_output_details,
    face_detector=face_detector,
    calibrator=calibrator,
    preprocessor=preprocessor,
    rd_service=rd_service,
    model_used=image_model_name,
)


audio_pipeline = AudioPipeline(
    calibrator=calibrator,
    rd_service=rd_service,
    aud_interpreter=aud_interpreter,
    aud_input_details=aud_input_details,
    aud_output_details=aud_output_details,
)

stream_pipeline = StreamPipeline(
    interpreter=interpreter,
    input_details=input_details,
    output_details=output_details,
    face_detector=face_detector,
    quality_filter=quality_filter,
    temporal_filter=TemporalFilter(window_size=app_config.STREAM_WINDOW_SIZE),
    calibrator=calibrator,
    preprocessor=preprocessor,
)

offline_pipeline = OfflinePipeline(
    interpreter=interpreter,
    input_details=input_details,
    output_details=output_details,
)

# InMemory databases for Job and Stream tracking
jobs_db = {}
streams_db = {}
active_stream_workers: Dict[str, Any] = {}

class LinkVerifyRequest(BaseModel):
    url: str

class ImageLinkVerifyRequest(BaseModel):
    url: str

class StreamVerifyRequest(BaseModel):
    stream_url: str

# ---- Utility functions ----

def _attach_engine(result, kind: str):
    """Stamp the engine-transparency block onto any verification result.

    The Reality Defender sub-result is read straight off the payload so the
    block always reflects the engine that actually produced this verdict,
    including rd_partial and the request id.

    Job/session envelopes wrap the verdict in a ``result`` key; those get the
    block on both the envelope and the inner verdict, so a client reading
    either shape finds it.
    """
def _append_gemini_engine(result: Any, ai_explanation: Any) -> None:
    if isinstance(result, dict) and isinstance(ai_explanation, dict):
        if ai_explanation.get("status") == "success":
            engines = result.setdefault("engines_used", ["local"])
            if "gemini" not in engines:
                engines.append("gemini")


def _attach_engine(result: Any, kind: str) -> Any:
    """Enrich the given verification result with the engine transparency block."""
    if not isinstance(result, dict):
        return result
    inner = result.get("result")
    rd_result = result.get("reality_defender")
    if rd_result is None and isinstance(inner, dict):
        rd_result = inner.get("reality_defender")
    attach_engine_transparency(result, kind=kind, rd_result=rd_result)
    if isinstance(inner, dict) and "engine" not in inner:
        attach_engine_transparency(inner, kind=kind, rd_result=rd_result)

    # Ensure transparency fields are present on top-level result
    if "engines_used" not in result:
        engines = ["local"]
        if rd_result and rd_result.get("status") == "success" and not rd_result.get("partial"):
            engines.append("reality_defender")
        result["engines_used"] = engines

    if "face_detector_used" not in result and kind in ("image", "video", "link"):
        result["face_detector_used"] = (
            face_detector.loaded_detectors[0].lower() if getattr(face_detector, "loaded_detectors", None) else "none"
        )

    if "degraded" not in result:
        rd_failed = bool(rd_result and (rd_result.get("status") != "success" or rd_result.get("partial")))
        result["degraded"] = rd_failed

    return result



def get_file_hash(file_path: str) -> str:
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def get_bytes_hash(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def download_video_from_url(url: str, timeout: int = 120) -> str:
    parsed = urlparse(url)
    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}

    if "drive.google.com" in parsed.netloc:
        url = _resolve_google_drive(url)
    elif "dropbox.com" in parsed.netloc:
        url = _resolve_dropbox(url)

    response = requests.get(url, headers=headers, timeout=timeout, stream=True)
    response.raise_for_status()

    suffix = ".mp4"
    content_type = response.headers.get("content-type", "")
    if "video" in content_type or url.endswith(".mp4"):
        suffix = ".mp4"

    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        total = int(response.headers.get("content-length", 0))
        downloaded = 0
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                tmp.write(chunk)
                downloaded += len(chunk)

    return tmp.name

def _resolve_google_drive(url: str) -> str:
    if "/file/d/" in url:
        file_id = url.split("/file/d/")[1].split("/")[0]
        return f"https://drive.google.com/uc?export=download&id={file_id}"
    return url

def _resolve_dropbox(url: str) -> str:
    if "dropbox.com" in url and "dl=0" in url:
        return url.replace("dl=0", "dl=1")
    return url

def calculate_frame_consistency(faces):
    if len(faces) < 2:
        return 100.0
    correlations = []
    for i in range(len(faces) - 1):
        hist1 = cv2.calcHist([faces[i]], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
        hist2 = cv2.calcHist([faces[i+1]], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
        cv2.normalize(hist1, hist1)
        cv2.normalize(hist2, hist2)
        corr = cv2.compareHist(hist1, hist2, cv2.HISTCMP_CORREL)
        correlations.append(corr)
    avg_corr = float(np.mean(correlations))
    score = max(0.0, avg_corr * 100.0)
    return round(score, 2)

def calculate_tracking_confidence(boxes):
    if not boxes:
        return 0.0
    if len(boxes) < 2:
        return 100.0
    displacements = []
    for i in range(len(boxes) - 1):
        b1 = boxes[i]
        b2 = boxes[i+1]
        c1_x = b1[0] + b1[2]/2
        c1_y = b1[1] + b1[3]/2
        c2_x = b2[0] + b2[2]/2
        c2_y = b2[1] + b2[3]/2
        dist = np.sqrt((c1_x - c2_x)**2 + (c1_y - c2_y)**2)
        avg_size = (b1[2] + b1[3] + b2[2] + b2[3]) / 4
        norm_dist = dist / max(1.0, avg_size)
        displacements.append(norm_dist)
    avg_disp = float(np.mean(displacements))
    score = max(0.0, 100.0 - (avg_disp * 150.0))
    return round(score, 2)

def calculate_metadata_score(video_path):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        return 0.0
    w = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
    h = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
    fps = cap.get(cv2.CAP_PROP_FPS)
    count = cap.get(cv2.CAP_PROP_FRAME_COUNT)
    cap.release()
    score = 100.0
    if w <= 0 or h <= 0:
        score -= 30.0
    if fps <= 0 or fps > 120:
        score -= 30.0
    if count <= 0:
        score -= 40.0
    return max(0.0, score)

def calculate_ocr_confidence(video_path, max_frames=5):
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total_frames <= 0:
        cap.release()
        return 0.0
    frame_indices = np.linspace(0, total_frames - 1, min(total_frames, max_frames), dtype=int)
    text_scores = []
    for idx in frame_indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            continue
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        grad_x = cv2.Sobel(gray, cv2.CV_8U, 1, 0, ksize=3)
        _, thresh = cv2.threshold(grad_x, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        edge_ratio = np.sum(thresh == 255) / thresh.size
        text_scores.append(edge_ratio)
    cap.release()
    if not text_scores:
        return 0.0
    avg_ratio = float(np.mean(text_scores))
    if 0.005 < avg_ratio < 0.1:
        return round(80.0 + (avg_ratio * 150), 2)
    return 0.0

def preprocess_face(face_img):
    face_img = face_img.astype(np.float32)
    face_img = np.expand_dims(face_img, axis=0)
    return face_img

def run_inference(face_img):
    interpreter.set_tensor(input_details[0]['index'], face_img)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    return float(output[0][0])

# ---- Background Tasks ----

def download_and_verify_task(job_id: str, url: str):
    jobs_db[job_id] = {"status": "downloading", "progress": 0.05, "result": None}
    try:
        # Patch link_pipeline to emit status updates into jobs_db
        def _on_status(status: str, progress: float):
            # The pipeline emits its own terminal "completed" the moment the
            # verdict exists, which is *before* the result is stored here and
            # before the AI narrative is generated. Publish it as a
            # non-terminal state instead, otherwise a client polling
            # /analysis/{id} observes status=completed with result=null and
            # reads a null result as a failed analysis.
            if status == "completed":
                status = "analyzing"
            jobs_db[job_id]["status"] = status
            jobs_db[job_id]["progress"] = min(float(progress), 0.99)

        jobs_db[job_id]["status"] = "downloading"
        jobs_db[job_id]["progress"] = 0.1

        # Safety-net: hard wall-clock timeout around the entire pipeline so a
        # hung yt-dlp/analysis can never leave the job stuck in "downloading".
        # The download step already enforces URL_DOWNLOAD_TIMEOUT; this margin
        # covers frame extraction + inference.
        overall_timeout = app_config.URL_DOWNLOAD_TIMEOUT + 180
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(link_pipeline.process, url, source="Video Link", status_cb=_on_status)
            try:
                result = future.result(timeout=overall_timeout)
            except FuturesTimeoutError:
                logger.error(
                    f"[download_and_verify_task] job_id={job_id} pipeline exceeded "
                    f"{overall_timeout}s wall-clock limit for URL: {url}"
                )
                jobs_db[job_id]["status"] = "failed"
                jobs_db[job_id]["error"] = (
                    f"Analysis timed out after {overall_timeout}s. The video may be "
                    f"too large, the server may be under heavy load, or the platform "
                    f"is blocking automated downloads. Try a direct video link or "
                    f"upload the file directly."
                )
                return

        # If the pipeline returned a failed report (download blocked, media
        # decode error, etc.) propagate it as a "failed" job so the UI surfaces
        # a clear error instead of an INCONCLUSIVE verdict with all-zero scores.
        failed_statuses = ("DOWNLOAD_FAILED", "PROCESSING_ERROR", "UNSUPPORTED")
        if result.get("analysis_status") in failed_statuses or result.get("video_retrieved") is False:
            reason = result.get("reason") or "Unable to retrieve the video from this link."
            jobs_db[job_id]["result"] = result
            jobs_db[job_id]["progress"] = 1.0
            jobs_db[job_id]["status"] = "failed"
            jobs_db[job_id]["error"] = reason
            logger.warning(
                f"[download_and_verify_task] job_id={job_id} link verification failed: "
                f"{result.get('analysis_status')} — {reason}"
            )
            return

        # Append Gemini AI forensic explanation to result
        try:
            ai_explanation = gemini_service.generate_forensic_explanation(result)
            result["aiExplanation"] = ai_explanation
            _append_gemini_engine(result, ai_explanation)
        except Exception as ai_err:
            logger.warning(f"[download_and_verify_task] Gemini AI explanation failed: {ai_err}")


        _attach_engine(result, "link")
        cache.set(url, result)

        # Publish the payload *before* flipping status: a client polling
        # /analysis/{id} would otherwise observe status=completed with
        # result=null in the window between the two assignments.
        jobs_db[job_id]["result"] = result
        jobs_db[job_id]["progress"] = 1.0
        jobs_db[job_id]["status"] = "completed"
    except Exception as e:
        jobs_db[job_id]["status"] = "failed"
        jobs_db[job_id]["error"] = str(e)
        logger.error(f"[download_and_verify_task] job_id={job_id} failed: {e}")

# ---- Forensic Pipeline ----

def run_full_pipeline(video_path: str, source: str = "Local Upload") -> dict:
    try:
        return video_pipeline.process(video_path, source=source)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))

# ---- API Routing ----

@app.get("/")
def home():
    return {"message": "Veriframe API is running", "version": "2.0.0"}

@app.get("/health")
def health():
    return {
        "status": "healthy",
        "model_loaded": model_path is not None and os.path.exists(model_path),
        "model_path": model_path,
        "retinaface_available": face_detector.retinaface is not None,
        "scrfd_available": face_detector.scrfd is not None,
        "cache_entries": cache.stats()["entries"],
        "gemini_configured": gemini_service.is_configured(),
        "engine": engine_transparency(kind="video", rd_result=None),
    }

@app.get("/version")
def version():
    return {
        "api_version": "2.0.0",
        "model": "veriframe_model.tflite",
        "backend": "FastAPI",
        "face_detection": "RetinaFace -> SCRFD -> MTCNN -> MediaPipe -> Haar",
        "preprocessing": "CLAHE + Gamma + ImageNet Normalization",
        "temporal_filtering": "Weighted Median-Mean Smoothing",
        "calibration": "Temperature Scaling + Platt Scaling",
        "caching": "SHA256-based file cache",
        "max_frames": app_config.MAX_FRAMES,
        "target_frames": app_config.TARGET_FRAMES,
        "input_size": list(app_config.INPUT_SIZE),
        "engine": engine_transparency(kind="video", rd_result=None),
    }

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    suffix = os.path.splitext(file.filename or "")[1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        video_path = tmp.name

    try:
        result = await run_in_threadpool(run_full_pipeline, video_path, "Local Upload")
        try:
            result["aiExplanation"] = await run_in_threadpool(gemini_service.generate_forensic_explanation, result)
            _append_gemini_engine(result, result["aiExplanation"])
        except Exception as ai_err:
            logger.warning(f"[predict] Gemini AI explanation failed: {ai_err}")
        return _attach_engine(result, "video")
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process video: {str(e)}")
    finally:
        if os.path.exists(video_path):
            os.remove(video_path)


@app.post("/verify/image")
async def verify_image(file: UploadFile = File(...)):
    suffix = os.path.splitext(file.filename or "")[1] or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        # The pipeline is CPU/TFLite bound and may call out to Reality Defender.
        # Running it in a threadpool keeps the event loop free.
        result = await run_in_threadpool(image_pipeline.process, tmp_path, "Local Image")
        try:
            result["aiExplanation"] = await run_in_threadpool(gemini_service.generate_forensic_explanation, result)
            _append_gemini_engine(result, result["aiExplanation"])
        except Exception as ai_err:
            logger.warning(f"[verify_image] Gemini AI explanation failed: {ai_err}")
        return _attach_engine(result, "image")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[verify_image] Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to process image: {str(e)}")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

@app.post("/verify/image/link")
async def verify_image_link(request: ImageLinkVerifyRequest):
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }
    target_url = request.url.strip()
    try:
        resp = await run_in_threadpool(
            requests.get, target_url, headers=headers, timeout=25
        )
        if resp.status_code == 429:
            # Retry with mobile identifier in case of rate limit
            headers["User-Agent"] = "VeriFrame-Mobile/2.0 (Forensics Verification)"
            resp = await run_in_threadpool(requests.get, target_url, headers=headers, timeout=25)

        if resp.status_code != 200:
            raise HTTPException(status_code=400, detail=f"Failed to fetch image from URL: HTTP {resp.status_code}")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Unable to download image: {str(e)}")

    content_type = resp.headers.get("content-type", "").lower()
    raw_content = resp.content

    # If the user pasted a webpage link, try to extract the OpenGraph / Twitter meta image
    if "text/html" in content_type or raw_content.startswith(b"<!DOCTYPE") or raw_content.startswith(b"<html"):
        html_text = raw_content.decode("utf-8", errors="ignore")
        match = re.search(r'<meta[^>]+property=["\']og:image["\'][^>]+content=["\']([^"\']+)["\']', html_text, re.I)
        if not match:
            match = re.search(r'<meta[^>]+name=["\']twitter:image["\'][^>]+content=["\']([^"\']+)["\']', html_text, re.I)
        if match:
            extracted_url = match.group(1).replace("&amp;", "&")
            try:
                img_resp = await run_in_threadpool(requests.get, extracted_url, headers=headers, timeout=25)
                if img_resp.status_code == 200:
                    raw_content = img_resp.content
                    target_url = extracted_url
            except Exception as e:
                logger.warning(f"[verify_image_link] Failed to download extracted og:image: {e}")

    suffix = ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(raw_content)
        tmp_path = tmp.name

    try:
        result = await run_in_threadpool(image_pipeline.process, tmp_path, "Image Link")
        result["imageUrl"] = target_url
        try:
            result["aiExplanation"] = await run_in_threadpool(gemini_service.generate_forensic_explanation, result)
            _append_gemini_engine(result, result["aiExplanation"])
        except Exception as ai_err:
            logger.warning(f"[verify_image_link] Gemini AI explanation failed: {ai_err}")
        return _attach_engine(result, "image")
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=f"The URL does not contain a valid image: {str(ve)}")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[verify_image_link] Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to analyze image link: {str(e)}")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


@app.post("/verify/audio")
async def verify_audio(file: UploadFile = File(...)):
    suffix = os.path.splitext(file.filename or "")[1] or ".mp3"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        result = await run_in_threadpool(audio_pipeline.process, tmp_path, "Local Audio")
        try:
            result["aiExplanation"] = await run_in_threadpool(gemini_service.generate_forensic_explanation, result)
            _append_gemini_engine(result, result["aiExplanation"])
        except Exception as ai_err:
            logger.warning(f"[verify_audio] Gemini AI explanation failed: {ai_err}")
        return _attach_engine(result, "audio")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[verify_audio] Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to process audio: {str(e)}")

    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

class AiExplainRequest(BaseModel):
    """Accepts a partial or full verification result and returns a Gemini AI explanation."""
    verdict: str = "INCONCLUSIVE"
    fineVerdict: Optional[str] = None
    fakeProbability: float = 0.0
    authenticityScore: float = 100.0
    mediaType: Optional[str] = "media"
    source: Optional[str] = "upload"
    detectedEvidence: Optional[list] = None
    forensicObservations: Optional[list] = None

@app.post("/ai/explain")
async def ai_explain(request: AiExplainRequest):
    """Standalone endpoint: generate Gemini AI forensic narrative for any verification payload."""
    report = {
        "verdict": request.verdict,
        "fineVerdict": request.fineVerdict or request.verdict,
        "fakeProbability": request.fakeProbability,
        "authenticityScore": request.authenticityScore,
        "mediaType": request.mediaType,
        "source": request.source,
        "detectedEvidence": request.detectedEvidence or [],
        "forensicObservations": request.forensicObservations or [],
    }
    try:
        explanation = await run_in_threadpool(gemini_service.generate_forensic_explanation, report)
        return {"status": "success", "explanation": explanation}
    except Exception as e:
        logger.error(f"[ai_explain] Error: {e}")
        raise HTTPException(status_code=500, detail=f"AI explanation failed: {str(e)}")



@app.post("/verify/link")
def verify_link(request: LinkVerifyRequest, background_tasks: BackgroundTasks):
    job_id = f"job-{int(time.time() * 1000)}"
    jobs_db[job_id] = {"status": "pending", "progress": 0.0, "result": None}
    background_tasks.add_task(download_and_verify_task, job_id, request.url)
    # The real engine block is attached once the job completes (see
    # download_and_verify_task); this ack reports which engine will run.
    return {"job_id": job_id, "engine": engine_transparency(kind="link", rd_result=None)}

@app.post("/verify/stream")
def verify_stream(request: StreamVerifyRequest):
    session_id = f"stream-{int(time.time() * 1000)}"
    streams_db[session_id] = stream_pipeline.create_session(request.stream_url)
    return {"session_id": session_id, "engine": engine_transparency(kind="stream", rd_result=None)}

@app.post("/analyze/stream/frame")
async def analyze_stream_frame(frame_base64: str = Form(...), session_id: str = Form(...)):
    if session_id not in streams_db:
        raise HTTPException(status_code=404, detail="Stream session not found.")

    session = streams_db[session_id]
    result = await run_in_threadpool(stream_pipeline.process_frame, session, frame_base64)

    legacy_verdict = result["verdict"]
    if legacy_verdict == "INSUFFICIENT_DATA":
        # No frame has been scored yet. The legacy contract maps UNCERTAIN to
        # "authentic", which would report a firm AUTHENTIC verdict derived from
        # no evidence at all, so this state is surfaced as "unknown".
        legacy_prediction = "unknown"
    elif legacy_verdict == "AUTHENTIC":
        legacy_prediction = "authentic"
    elif legacy_verdict == "LIKELY_AUTHENTIC":
        legacy_prediction = "authentic"
    elif legacy_verdict == "UNCERTAIN":
        # Reported as its own state: mapping an uncertain score to "authentic"
        # would present a firm AUTHENTIC verdict the backend never made.
        legacy_prediction = "inconclusive"
    else:
        legacy_prediction = "manipulated"

    return _attach_engine({
        "session_confidence_score": result["session_confidence_score"],
        "verdict": legacy_prediction,
        "model_used": "MobileNet Ensemble (Cloud Stream)",
        "authenticity_score": result.get("authenticity_score"),
        "fake_probability": result.get("fake_probability"),
        "frames_processed": result.get("frames_processed"),
        "faces_detected": result.get("faces_detected"),
        "scored_frames": result.get("scored_frames"),
    }, "stream")

@app.get("/analysis/{id}")
def get_analysis(id: str):
    if id in jobs_db:
        return jobs_db[id]

    if id in streams_db:
        session = streams_db[id]
        if len(session["scores"]) == 0:
            return {"status": "failed", "error": "No biometric frames analyzed in the active stream session."}
        try:
            return _attach_engine(stream_pipeline.get_session_summary(session), "stream")
        except ValueError as ve:
            return {"status": "failed", "error": str(ve)}

    raise HTTPException(status_code=404, detail="Job/Session ID not found.")

@app.post("/report/create")
def report_create(request: dict):
    session_id = request.get("session_id", "")
    job_id = request.get("job_id", "")

    if job_id and job_id in jobs_db:
        job = jobs_db[job_id]
        if job["status"] == "completed":
            return _attach_engine(job["result"], "link")
        raise HTTPException(status_code=400, detail=f"Job analysis in status: {job['status']}")

    if session_id and session_id in streams_db:
        session = streams_db[session_id]
        if len(session["scores"]) == 0:
            raise HTTPException(status_code=400, detail="Biometric stream analysis failed: No frames with faces detected.")
        try:
            summary = stream_pipeline.get_session_summary(session)
            return _attach_engine(summary["result"], "stream")
        except ValueError as ve:
            raise HTTPException(status_code=400, detail=str(ve))

    raise HTTPException(status_code=400, detail="Invalid request parameters. Provide session_id or job_id.")

@app.post("/report/send")
def report_send(request: dict):
    report_id = request.get("report_id", "")
    target = request.get("target", "")
    if not report_id:
        raise HTTPException(status_code=400, detail="Missing report_id.")
    return {"message": f"Report {report_id} escalated to {target or 'authorities'} successfully."}

# ---- Database query endpoints ----

@app.get("/reports")
def get_reports(limit: int = 50, offset: int = 0):
    reports = list_reports(limit=limit, offset=offset)
    return {"reports": reports, "limit": limit, "offset": offset}

@app.get("/reports/{report_hash}")
def get_report(report_hash: str):
    report = get_report_by_hash(report_hash)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found.")
    return report

# ---- New v2 endpoints ----

class DetectVideoRequest(BaseModel):
    video_base64: Optional[str] = None
    video_url: Optional[str] = None

class DetectUrlRequest(BaseModel):
    url: str

class DetectStreamRequest(BaseModel):
    stream_url: str

# ---- Live stream endpoints (RTSP/RTMP/HLS) ----

@app.post("/stream/start")
def stream_start(request: DetectStreamRequest):
    from workers.stream_worker import StreamWorker, StreamWorkerConfig
    session_id = f"stream-{int(time.time() * 1000)}"
    worker = StreamWorker(
        session_id=session_id,
        interpreter=interpreter,
        input_details=input_details,
        output_details=output_details,
        face_detector=face_detector,
        quality_filter=quality_filter,
        temporal_filter=TemporalFilter(window_size=app_config.STREAM_WINDOW_SIZE),
        calibrator=calibrator,
        preprocessor=preprocessor,
        config=StreamWorkerConfig(),
    )
    stream_url = request.stream_url
    started = False
    if stream_url.startswith("rtsp://"):
        started = worker.start_rtsp(stream_url)
    elif stream_url.startswith("rtmp://"):
        started = worker.start_rtmp(stream_url)
    elif ".m3u8" in stream_url or stream_url.startswith("http"):
        started = worker.start_hls(stream_url) if ".m3u8" in stream_url else worker.start_http_stream(stream_url)
    else:
        started = worker.start_http_stream(stream_url)

    if not started:
        raise HTTPException(status_code=400, detail=f"Failed to start stream: {stream_url}")

    active_stream_workers[session_id] = worker
    return {"session_id": session_id, "status": "streaming", "stream_url": stream_url}

@app.get("/stream/{session_id}/status")
def stream_status(session_id: str):
    worker = active_stream_workers.get(session_id)
    if not worker:
        raise HTTPException(status_code=404, detail="Stream session not found.")
    return worker.get_status()

@app.post("/stream/{session_id}/stop")
def stream_stop(session_id: str):
    worker = active_stream_workers.pop(session_id, None)
    if not worker:
        raise HTTPException(status_code=404, detail="Stream session not found.")
    worker.stop()
    return {"status": "stopped", "session_id": session_id}

# ---- Utility functions ----
@app.post("/detect/video")
async def detect_video(request: DetectVideoRequest):
    try:
        if request.video_base64:
            video_bytes = base64.b64decode(request.video_base64)
            video_hash = get_bytes_hash(video_bytes)
            cached = cache.get(video_hash)
            if cached:
                return JSONResponse(content={"cached": True, "result": cached})

            suffix = ".mp4"
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                tmp.write(video_bytes)
                video_path = tmp.name

            try:
                result = await run_in_threadpool(video_pipeline.process, video_path, "Base64 Upload")
                _attach_engine(result, "video")
                cache.set(video_hash, result)
                return JSONResponse(content={"cached": False, "result": result})
            finally:
                if os.path.exists(video_path):
                    os.remove(video_path)

        elif request.video_url:
            result = await run_in_threadpool(link_pipeline.process, request.video_url, "URL Upload")
            _attach_engine(result, "link")
            cache.set(request.video_url, result)
            return JSONResponse(content={"cached": False, "result": result})
        else:
            raise HTTPException(status_code=400, detail="Provide video_base64 or video_url")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/detect/url")
def detect_url(request: DetectUrlRequest, background_tasks: BackgroundTasks):
    job_id = f"detect-url-{int(time.time() * 1000)}"
    jobs_db[job_id] = {"status": "pending", "progress": 0.0, "result": None}
    background_tasks.add_task(download_and_verify_task, job_id, request.url)
    return {"job_id": job_id, "engine": engine_transparency(kind="link", rd_result=None)}

@app.post("/detect/stream")
def detect_stream(request: DetectStreamRequest):
    session_id = f"detect-stream-{int(time.time() * 1000)}"
    streams_db[session_id] = stream_pipeline.create_session(request.stream_url)
    return {"session_id": session_id, "engine": engine_transparency(kind="stream", rd_result=None)}

@app.post("/detect/stream/frame")
async def detect_stream_frame(frame: UploadFile = File(...), session_id: str = Form(...)):
    if session_id not in streams_db:
        raise HTTPException(status_code=404, detail="Stream session not found.")

    contents = await frame.read()
    frame_base64 = f"data:image/jpeg;base64,{base64.b64encode(contents).decode()}"

    session = streams_db[session_id]
    result = await run_in_threadpool(stream_pipeline.process_frame, session, frame_base64)

    return _attach_engine({
        "session_confidence_score": result["session_confidence_score"],
        "verdict": result["verdict"],
        "frames_processed": session["frame_count"],
        "faces_detected": session["faces_detected"],
    }, "stream")