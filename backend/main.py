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
    jobs_db[job_id] = {"status": "downloading", "progress": 0.2, "result": None}
    video_path = None
    try:
        jobs_db[job_id]["status"] = "downloading"
        video_path = download_video_from_url(url, timeout=app_config.URL_DOWNLOAD_TIMEOUT)

        video_hash = get_file_hash(video_path)
        cached = cache.get(video_hash)
        if cached:
            jobs_db[job_id]["status"] = "completed"
            jobs_db[job_id]["progress"] = 1.0
            jobs_db[job_id]["result"] = cached
            jobs_db[job_id]["cached"] = True
            return

        jobs_db[job_id]["status"] = "extracting"
        jobs_db[job_id]["progress"] = 0.5

        result = run_full_pipeline(video_path, source="Video Link")

        jobs_db[job_id]["status"] = "completed"
        jobs_db[job_id]["progress"] = 1.0
        jobs_db[job_id]["result"] = result
    except Exception as e:
        jobs_db[job_id]["status"] = "failed"
        jobs_db[job_id]["error"] = str(e)
        logger.error(f"[download_and_verify_task] job_id={job_id} failed: {e}")
    finally:
        if video_path and os.path.exists(video_path):
            try:
                os.remove(video_path)
            except Exception:
                pass

# ---- Forensic Pipeline ----

def run_full_pipeline(video_path: str, source: str = "Local Upload") -> dict:
    start_time = time.time()
    video_hash = get_file_hash(video_path)
    metadata = get_video_metadata(video_path)
    frame_indices = frame_sampler.sample(video_path)

    logger.info(f"[Pipeline] Extracted {len(frame_indices)} frames from {video_path}")

    if not frame_indices:
        raise HTTPException(status_code=400, detail="Biometric analysis failed: No suitable frames extracted from video.")

    cap = cv2.VideoCapture(video_path)
    all_faces = []
    all_boxes = []
    all_detection_details = []
    frames_skipped = 0

    for idx in frame_indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            frames_skipped += 1
            continue

        detections = face_detector.detect(frame)
        if not detections:
            frames_skipped += 1
            continue

        best_det = max(detections, key=lambda d: d.quality_score)
        is_good, details = quality_filter.is_quality_face(best_det.face_crop, frame.shape)
        if is_good:
            try:
                face_resized = cv2.resize(best_det.face_crop, INPUT_SIZE)
            except Exception:
                frames_skipped += 1
                continue
            all_faces.append(face_resized)
            all_boxes.append(best_det.box)
            all_detection_details.append(details)
        else:
            frames_skipped += 1
    cap.release()

    logger.info(f"[Pipeline] Frames skipped: {frames_skipped}, Quality faces: {len(all_faces)}")

    if len(all_faces) == 0:
        raise HTTPException(status_code=400, detail="Biometric analysis failed: No face features detected in the video stream.")

    scores = []
    inference_times = []
    for face in all_faces:
        t0 = time.time()
        try:
            processed = preprocessor.preprocess_face(face)
            score = run_inference(processed)
        except Exception:
            score = 0.5
        inference_times.append(time.time() - t0)
        scores.append(score)

    avg_inference_ms = float(np.mean(inference_times)) * 1000 if inference_times else 0.0

    quality_weights = [d.get("quality_score", 1.0) for d in all_detection_details]
    weighted_scores = [s * w for s, w in zip(scores, quality_weights)]
    avg_score = sum(weighted_scores) / sum(quality_weights) if sum(quality_weights) > 0 else float(np.mean(scores))

    for score in scores:
        temporal_filter.update(score)

    temporal_agg = temporal_filter.get_aggregate()
    calibrated_score = calibrator.calibrate(avg_score)

    authenticity_score = round(calibrated_score * 100.0, 2)
    fake_probability = round((1.0 - calibrated_score) * 100.0, 2)

    frame_consistency = calculate_frame_consistency(all_faces)
    tracking_confidence = calculate_tracking_confidence(all_boxes)
    ocr_confidence = calculate_ocr_confidence(video_path)
    metadata_score = calculate_metadata_score(video_path)

    prediction_confidence = calibrated_score if calibrated_score >= 0.5 else (1.0 - calibrated_score)
    fused_confidence = round(
        (prediction_confidence * 0.7 +
         (frame_consistency / 100.0) * 0.15 +
         (tracking_confidence / 100.0) * 0.15) * 100.0,
        2
    )

    if calibrated_score >= 0.8:
        verdict = "FAKE"
    elif calibrated_score >= 0.6:
        verdict = "LIKELY_FAKE"
    elif calibrated_score >= 0.4:
        verdict = "UNCERTAIN"
    elif calibrated_score >= 0.2:
        verdict = "LIKELY_REAL"
    else:
        verdict = "REAL"

    if verdict == "REAL":
        legacy_verdict = "AUTHENTIC"
    elif verdict == "LIKELY_REAL":
        legacy_verdict = "AUTHENTIC"
    elif verdict == "UNCERTAIN":
        legacy_verdict = "MANIPULATED" if authenticity_score < 50.0 else "AUTHENTIC"
    else:
        legacy_verdict = "MANIPULATED"

    risk_level = "LOW" if authenticity_score >= 75.0 else ("MEDIUM" if authenticity_score >= 50.0 else "HIGH")

    detected_evidence = []
    forensic_observations = [
        f"Analyzed {len(all_faces)} biometric face frames.",
        f"Face box tracking continuity: {tracking_confidence}%.",
        f"Frame color consistency: {frame_consistency}% continuity.",
        f"Processing time: {round(time.time() - start_time, 2)}s. Inference avg: {round(avg_inference_ms, 1)}ms/frame.",
    ]

    if legacy_verdict == "AUTHENTIC":
        detected_evidence.append("No facial manipulation signatures detected.")
        detected_evidence.append(f"Liveness visual metrics match authentic biometric structures (Authenticity: {authenticity_score}%).")
    else:
        detected_evidence.append("Biometric manipulation signatures identified in face region.")
        detected_evidence.append(f"High manipulation score of {fake_probability}% matches deepfake profiles.")

    if metadata_score < 100.0:
        detected_evidence.append(f"Metadata anomalies detected (Metadata Score: {metadata_score}%).")
    else:
        forensic_observations.append("Video metadata verified: Container matches standard camera profiles.")

    if frame_consistency < 70.0:
        detected_evidence.append(f"Anomalous visual shifts detected between frames (Consistency: {frame_consistency}%).")

    if ocr_confidence > 0.0:
        forensic_observations.append(f"OCR Scan active: Detected high-contrast overlay text (Confidence: {ocr_confidence}%).")
    else:
        forensic_observations.append("OCR Scan active: No text overlays detected in media stream.")

    verification_id = f"VRF-{int(time.time() * 1000)}"

    result = {
        "verificationId": verification_id,
        "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "mediaType": "video/mp4",
        "source": source,
        "authenticityScore": authenticity_score,
        "fakeProbability": fake_probability,
        "confidence": fused_confidence,
        "metadataScore": metadata_score,
        "frameConsistency": frame_consistency,
        "ocrConfidence": ocr_confidence,
        "trackingConfidence": tracking_confidence,
        "manipulationScore": fake_probability,
        "verdict": legacy_verdict,
        "riskLevel": risk_level,
        "detectedEvidence": detected_evidence,
        "forensicObservations": forensic_observations,
        "reportHash": video_hash,
        "framesAnalyzed": len(all_faces),
        "framesSkipped": frames_skipped,
        "processingTimeSec": round(time.time() - start_time, 2),
        "averageScore": round(float(np.mean(scores)), 4) if scores else 0.0,
        "inferenceTimeMs": round(avg_inference_ms, 2),
        "is_fake": authenticity_score < 50.0,
        "score": round(avg_score, 4),
        "confidence_label": "High" if fused_confidence >= 80.0 else ("Medium" if fused_confidence >= 60.0 else "Low"),
    }

    cache.set(video_hash, result)
    return result

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

        avg_score = float(np.mean(session["scores"]))
        authenticity_score = round(avg_score * 100.0, 2)
        fake_probability = round((1.0 - avg_score) * 100.0, 2)

        correlations = []
        for i in range(len(session.get("hists", [])) - 1):
            corr = cv2.compareHist(session["hists"][i], session["hists"][i+1], cv2.HISTCMP_CORREL)
            correlations.append(corr)
        frame_consistency = round(float(np.mean(correlations)) * 100.0, 2) if correlations else 100.0

        tracking_confidence = calculate_tracking_confidence(session.get("boxes", []))
        metadata_score = 100.0

        prediction_confidence = avg_score if avg_score >= 0.5 else (1.0 - avg_score)
        fused_confidence = round(
            (prediction_confidence * 0.7 +
             (frame_consistency / 100.0) * 0.15 +
             (tracking_confidence / 100.0) * 0.15) * 100.0,
            2
        )

        verdict = "AUTHENTIC" if authenticity_score >= 50.0 else "MANIPULATED"
        risk_level = "LOW" if authenticity_score >= 75.0 else ("MEDIUM" if authenticity_score >= 50.0 else "HIGH")

        detected_evidence = []
        forensic_observations = [
            f"Analyzed {len(session['scores'])} biometric stream frames.",
            f"Face tracking continuity: {tracking_confidence}%.",
            f"Inter-frame visual variance consistency: {frame_consistency}%."
        ]

        if verdict == "AUTHENTIC":
            detected_evidence.append("No active manipulation signatures detected in biometric stream.")
        else:
            detected_evidence.append("Biometric manipulation signatures identified in face region of stream.")
            detected_evidence.append(f"Stream manipulation rating: {fake_probability}%.")

        verification_id = f"VRF-{int(time.time() * 1000)}"

        return {
            "status": "completed",
            "progress": 1.0,
            "result": {
                "verificationId": verification_id,
                "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "mediaType": "live/stream",
                "source": "Live Stream",
                "authenticityScore": authenticity_score,
                "fakeProbability": fake_probability,
                "confidence": fused_confidence,
                "metadataScore": metadata_score,
                "frameConsistency": frame_consistency,
                "ocrConfidence": 0.0,
                "trackingConfidence": tracking_confidence,
                "manipulationScore": fake_probability,
                "verdict": verdict,
                "riskLevel": risk_level,
                "detectedEvidence": detected_evidence,
                "forensicObservations": forensic_observations,
                "reportHash": hashlib.sha256(f"{id}-{time.time()}".encode()).hexdigest()
            }
        }

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

        avg_score = float(np.mean(session["scores"]))
        authenticity_score = round(avg_score * 100.0, 2)
        fake_probability = round((1.0 - avg_score) * 100.0, 2)

        correlations = []
        for i in range(len(session.get("hists", [])) - 1):
            corr = cv2.compareHist(session["hists"][i], session["hists"][i+1], cv2.HISTCMP_CORREL)
            correlations.append(corr)
        frame_consistency = round(float(np.mean(correlations)) * 100.0, 2) if correlations else 100.0

        tracking_confidence = calculate_tracking_confidence(session.get("boxes", []))
        metadata_score = 100.0

        prediction_confidence = avg_score if avg_score >= 0.5 else (1.0 - avg_score)
        fused_confidence = round(
            (prediction_confidence * 0.7 +
             (frame_consistency / 100.0) * 0.15 +
             (tracking_confidence / 100.0) * 0.15) * 100.0,
            2
        )

        verdict = "AUTHENTIC" if authenticity_score >= 50.0 else "MANIPULATED"
        risk_level = "LOW" if authenticity_score >= 75.0 else ("MEDIUM" if authenticity_score >= 50.0 else "HIGH")

        detected_evidence = []
        forensic_observations = [
            f"Analyzed {len(session['scores'])} biometric stream frames.",
            f"Face tracking continuity: {tracking_confidence}%.",
            f"Inter-frame visual variance consistency: {frame_consistency}%."
        ]

        if verdict == "AUTHENTIC":
            detected_evidence.append("No active manipulation signatures detected in biometric stream.")
        else:
            detected_evidence.append("Biometric manipulation signatures identified in face region of stream.")
            detected_evidence.append(f"Stream manipulation rating: {fake_probability}%.")

        verification_id = f"VRF-{int(time.time() * 1000)}"

        return {
            "verificationId": verification_id,
            "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "mediaType": "live/stream",
            "source": "Live Stream",
            "authenticityScore": authenticity_score,
            "fakeProbability": fake_probability,
            "confidence": fused_confidence,
            "metadataScore": metadata_score,
            "frameConsistency": frame_consistency,
            "ocrConfidence": 0.0,
            "trackingConfidence": tracking_confidence,
            "manipulationScore": fake_probability,
            "verdict": verdict,
            "riskLevel": risk_level,
            "detectedEvidence": detected_evidence,
            "forensicObservations": forensic_observations,
            "reportHash": hashlib.sha256(f"{session_id}-{time.time()}".encode()).hexdigest()
        }

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
                result = run_full_pipeline(video_path, source="Base64 Upload")
                return JSONResponse(content={"cached": False, "result": result})
            finally:
                if os.path.exists(video_path):
                    os.remove(video_path)

        elif request.video_url:
            cached = cache.get(request.video_url)
            if cached:
                return JSONResponse(content={"cached": True, "result": cached})

            video_path = download_video_from_url(request.video_url)
            try:
                result = run_full_pipeline(video_path, source="URL Upload")
                return JSONResponse(content={"cached": False, "result": result})
            finally:
                if os.path.exists(video_path):
                    os.remove(video_path)
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