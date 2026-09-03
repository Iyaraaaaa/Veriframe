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
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, Any, Optional
import requests

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
from preprocessing.preprocessor import FramePreprocessor
from cache.result_cache import ResultCache
from database.connection import init_db, upsert_job, insert_report, insert_history, get_report_by_hash, list_reports
from database.models import JobRecord, ReportRecord, CacheEntry, AnalysisHistory
from utils.video import get_video_metadata, decode_base64_frame
from utils.image import compute_face_quality_score, pad_to_square

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
    logger.info(f"[Main] Model loaded: {model_path}")
except Exception as e:
    logger.error(f"[Main] Model load failed: {e}")
    raise RuntimeError(f"Failed to load TFLite model: {e}")

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

class StreamVerifyRequest(BaseModel):
    stream_url: str

# ---- Utility functions ----

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
            jobs_db[job_id]["status"] = status
            jobs_db[job_id]["progress"] = progress

        jobs_db[job_id]["status"] = "downloading"
        jobs_db[job_id]["progress"] = 0.1
        result = link_pipeline.process(url, source="Video Link", status_cb=_on_status)
        cache.set(url, result)

        jobs_db[job_id]["status"] = "completed"
        jobs_db[job_id]["progress"] = 1.0
        jobs_db[job_id]["result"] = result
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
    }

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    suffix = os.path.splitext(file.filename or "")[1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        video_path = tmp.name

    try:
        result = run_full_pipeline(video_path, source="Local Upload")
        return result
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process video: {str(e)}")
    finally:
        if os.path.exists(video_path):
            os.remove(video_path)

@app.post("/verify/link")
def verify_link(request: LinkVerifyRequest, background_tasks: BackgroundTasks):
    job_id = f"job-{int(time.time() * 1000)}"
    jobs_db[job_id] = {"status": "pending", "progress": 0.0, "result": None}
    background_tasks.add_task(download_and_verify_task, job_id, request.url)
    return {"job_id": job_id}

@app.post("/verify/stream")
def verify_stream(request: StreamVerifyRequest):
    session_id = f"stream-{int(time.time() * 1000)}"
    streams_db[session_id] = stream_pipeline.create_session(request.stream_url)
    return {"session_id": session_id}

@app.post("/analyze/stream/frame")
async def analyze_stream_frame(frame_base64: str = File(...), session_id: str = File(...)):
    if session_id not in streams_db:
        raise HTTPException(status_code=404, detail="Stream session not found.")

    session = streams_db[session_id]
    result = stream_pipeline.process_frame(session, frame_base64)

    legacy_verdict = result["verdict"]
    if legacy_verdict == "AUTHENTIC":
        legacy_prediction = "authentic"
    elif legacy_verdict == "LIKELY_AUTHENTIC":
        legacy_prediction = "authentic"
    elif legacy_verdict == "UNCERTAIN":
        legacy_prediction = "authentic"
    else:
        legacy_prediction = "manipulated"

    return {
        "session_confidence_score": result["session_confidence_score"],
        "verdict": legacy_prediction,
        "model_used": "MobileNet Ensemble (Cloud Stream)"
    }

@app.get("/analysis/{id}")
def get_analysis(id: str):
    if id in jobs_db:
        return jobs_db[id]

    if id in streams_db:
        session = streams_db[id]
        if len(session["scores"]) == 0:
            return {"status": "failed", "error": "No biometric frames analyzed in the active stream session."}
        try:
            return stream_pipeline.get_session_summary(session)
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
            return job["result"]
        raise HTTPException(status_code=400, detail=f"Job analysis in status: {job['status']}")

    if session_id and session_id in streams_db:
        session = streams_db[session_id]
        if len(session["scores"]) == 0:
            raise HTTPException(status_code=400, detail="Biometric stream analysis failed: No frames with faces detected.")
        try:
            summary = stream_pipeline.get_session_summary(session)
            return summary["result"]
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
                result = video_pipeline.process(video_path, source="Base64 Upload")
                cache.set(video_hash, result)
                return JSONResponse(content={"cached": False, "result": result})
            finally:
                if os.path.exists(video_path):
                    os.remove(video_path)

        elif request.video_url:
            result = link_pipeline.process(request.video_url, source="URL Upload")
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
    return {"job_id": job_id}

@app.post("/detect/stream")
def detect_stream(request: DetectStreamRequest):
    session_id = f"detect-stream-{int(time.time() * 1000)}"
    streams_db[session_id] = stream_pipeline.create_session(request.stream_url)
    return {"session_id": session_id}

@app.post("/detect/stream/frame")
async def detect_stream_frame(frame: UploadFile = File(...), session_id: str = Form(...)):
    if session_id not in streams_db:
        raise HTTPException(status_code=404, detail="Stream session not found.")

    contents = await frame.read()
    frame_base64 = f"data:image/jpeg;base64,{base64.b64encode(contents).decode()}"

    session = streams_db[session_id]
    result = stream_pipeline.process_frame(session, frame_base64)

    return {
        "session_confidence_score": result["session_confidence_score"],
        "verdict": result["verdict"],
        "frames_processed": session["frame_count"],
        "faces_detected": session["faces_detected"],
    }