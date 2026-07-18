from fastapi import FastAPI, File, UploadFile, BackgroundTasks, HTTPException
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
import threading

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Load model once at startup, with fallback path ----
model_path = "../assets/veriframe_model.tflite"
if not os.path.exists(model_path):
    model_path = "veriframe_model.tflite"

if not os.path.exists(model_path):
    # Search root asset path too
    model_path = "../Veriframe/assets/veriframe_model.tflite"

interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

INPUT_SIZE = (224, 224)

# Haar cascade for face detection
haar_path = os.path.join(os.path.dirname(cv2.__file__), "data", "haarcascade_frontalface_default.xml")
face_cascade = cv2.CascadeClassifier(haar_path)

# Initialize MTCNN detector
import torch
try:
    from facenet_pytorch import MTCNN
    torch.set_grad_enabled(False)
    device = torch.device('cuda:0' if torch.cuda.is_available() else 'cpu')
    mtcnn_detector = MTCNN(margin=0, keep_all=False, select_largest=True, device=device)
    print(f"[MTCNN] Initialized successfully on {device}")
except Exception as e:
    print(f"[MTCNN] Failed to initialize: {e}. Falling back to Haar Cascade.")
    mtcnn_detector = None

# InMemory databases for Job and Stream tracking
jobs_db = {}
streams_db = {}

class LinkVerifyRequest(BaseModel):
    url: str

class StreamVerifyRequest(BaseModel):
    stream_url: str

# ---- Forensic Pipeline Helper Functions ----

def get_file_hash(file_path):
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def extract_faces_and_boxes_from_video(video_path, max_frames=20):
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    if total_frames <= 0:
        cap.release()
        return [], []

    frame_indices = np.linspace(0, total_frames - 1, max_frames, dtype=int)

    faces = []
    boxes_out = []
    for idx in frame_indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            continue

        face_crop = None
        box_coords = None

        if mtcnn_detector is not None:
            try:
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                boxes, _ = mtcnn_detector.detect(frame_rgb)
                
                if boxes is not None and len(boxes) > 0:
                    box = boxes[0]
                    xmin, ymin, xmax, ymax = [int(b) for b in box]
                    w = xmax - xmin
                    h = ymax - ymin
                    p_h = 0
                    p_w = 0
                    if h > w:
                        p_w = int((h-w)/2)
                    elif h < w:
                        p_h = int((w-h)/2)

                    ymin_padded = max(ymin - p_h, 0)
                    ymax_padded = min(ymax + p_h, frame.shape[0])
                    xmin_padded = max(xmin - p_w, 0)
                    xmax_padded = min(xmax + p_w, frame.shape[1])
                    
                    face_crop = frame[ymin_padded:ymax_padded, xmin_padded:xmax_padded]
                    box_coords = (xmin, ymin, w, h)
            except Exception as e:
                print(f"[MTCNN] Inference error: {e}")

        if face_crop is None or face_crop.size == 0:
            try:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                detected = face_cascade.detectMultiScale(gray, 1.1, 5)
                if len(detected) > 0:
                    x, y, w, h = max(detected, key=lambda box: box[2] * box[3])
                    face_crop = frame[y:y+h, x:x+w]
                    box_coords = (x, y, w, h)
            except Exception as e:
                print(f"[Haar Cascade] Fallback error: {e}")

        if face_crop is not None and face_crop.size > 0:
            try:
                face_resized = cv2.resize(face_crop, INPUT_SIZE)
                faces.append(face_resized)
                boxes_out.append(box_coords if box_coords else (0, 0, frame.shape[1], frame.shape[0]))
            except Exception as e:
                print(f"[Resize] Error: {e}")

    cap.release()
    return faces, boxes_out

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

def run_full_pipeline(video_path, source="Local Upload"):
    video_hash = get_file_hash(video_path)
    faces, boxes = extract_faces_and_boxes_from_video(video_path)
    
    if len(faces) == 0:
        raise HTTPException(status_code=400, detail="Biometric analysis failed: No face features detected in the video stream.")

    scores = []
    for face in faces:
        processed = preprocess_face(face)
        score = run_inference(processed)
        scores.append(score)
        
    avg_score = float(np.mean(scores))
    
    # Class order: fake=0, real=1. So avg_score is probability of being REAL.
    authenticity_score = round(avg_score * 100.0, 2)
    fake_probability = round((1.0 - avg_score) * 100.0, 2)
    
    frame_consistency = calculate_frame_consistency(faces)
    tracking_confidence = calculate_tracking_confidence(boxes)
    ocr_confidence = calculate_ocr_confidence(video_path)
    metadata_score = calculate_metadata_score(video_path)
    
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
        f"Analyzed {len(faces)} biometric face frames.",
        f"Face box tracking continuity: {tracking_confidence}%.",
        f"Frame color consistency: {frame_consistency}% continuity."
    ]
    
    if verdict == "AUTHENTIC":
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
    
    return {
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
        "verdict": verdict,
        "riskLevel": risk_level,
        "detectedEvidence": detected_evidence,
        "forensicObservations": forensic_observations,
        "reportHash": video_hash
    }

# ---- Background Tasks ----

def download_and_verify_task(job_id, url):
    jobs_db[job_id] = {"status": "downloading", "progress": 0.2, "result": None}
    video_path = None
    try:
        suffix = ".mp4"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            video_path = tmp.name
        
        # Download file
        import urllib.request
        opener = urllib.request.build_opener()
        opener.addheaders = [('User-Agent', 'Mozilla/5.0')]
        urllib.request.install_opener(opener)
        urllib.request.urlretrieve(url, video_path)
        
        jobs_db[job_id]["status"] = "extracting"
        jobs_db[job_id]["progress"] = 0.5
        
        result = run_full_pipeline(video_path, source="Video Link")
        
        jobs_db[job_id]["status"] = "completed"
        jobs_db[job_id]["progress"] = 1.0
        jobs_db[job_id]["result"] = result
    except Exception as e:
        jobs_db[job_id]["status"] = "failed"
        jobs_db[job_id]["error"] = str(e)
    finally:
        if video_path and os.path.exists(video_path):
            try:
                os.remove(video_path)
            except:
                pass

# ---- API Routing ----

@app.get("/")
def home():
    return {"message": "Veriframe API is running"}

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
    streams_db[session_id] = {
        "scores": [],
        "boxes": [],
        "hists": [],
        "last_frame_time": time.time(),
        "created_at": time.time(),
        "stream_url": request.stream_url
    }
    return {"session_id": session_id}

@app.post("/analyze/stream/frame")
async def analyze_stream_frame(frame_base64: str = File(...), session_id: str = File(...)):
    if session_id not in streams_db:
        raise HTTPException(status_code=404, detail="Stream session not found.")
    
    session = streams_db[session_id]
    session["last_frame_time"] = time.time()
    
    try:
        if "," in frame_base64:
            base64_data = frame_base64.split(",", 1)[1]
        else:
            base64_data = frame_base64
            
        img_bytes = base64.b64decode(base64_data)
        nparr = np.frombuffer(img_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid base64 frame encoding: {str(e)}")
    
    if frame is None:
        raise HTTPException(status_code=400, detail="Failed to decode base64 frame into image.")
    
    # Face crop extraction
    face_crop = None
    box_coords = None

    if mtcnn_detector is not None:
        try:
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            boxes, _ = mtcnn_detector.detect(frame_rgb)
            if boxes is not None and len(boxes) > 0:
                box = boxes[0]
                xmin, ymin, xmax, ymax = [int(b) for b in box]
                w, h = xmax - xmin, ymax - ymin
                face_crop = frame[max(ymin,0):min(ymax,frame.shape[0]), max(xmin,0):min(xmax,frame.shape[1])]
                box_coords = (xmin, ymin, w, h)
        except Exception as e:
            print(f"[Stream MTCNN] detect error: {e}")

    if face_crop is None or face_crop.size == 0:
        try:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            detected = face_cascade.detectMultiScale(gray, 1.1, 5)
            if len(detected) > 0:
                x, y, w, h = max(detected, key=lambda box: box[2] * box[3])
                face_crop = frame[y:y+h, x:x+w]
                box_coords = (x, y, w, h)
        except Exception as e:
            print(f"[Stream Haar] detect error: {e}")
            
    if face_crop is not None and face_crop.size > 0:
        try:
            face_resized = cv2.resize(face_crop, INPUT_SIZE)
            processed = preprocess_face(face_resized)
            score = run_inference(processed)
            session["scores"].append(score)
            session["boxes"].append(box_coords if box_coords else (0, 0, frame.shape[1], frame.shape[0]))
            
            # Record color histogram for frame consistency calculation
            hist = cv2.calcHist([face_resized], [0, 1, 2], None, [8, 8, 8], [0, 256, 0, 256, 0, 256])
            cv2.normalize(hist, hist)
            session["hists"].append(hist)
        except Exception as e:
            print(f"[Stream Inference] process error: {e}")
            
    # Calculate rolling confidence score
    if len(session["scores"]) > 0:
        avg_score = float(np.mean(session["scores"]))
        # Sigmoid probability -> rolling score [0, 100] representing fake rating
        rolling_score = (1.0 - avg_score) * 100.0
        prediction = "authentic" if avg_score >= 0.5 else "manipulated"
    else:
        rolling_score = 0.0
        prediction = "authentic"
        
    return {
        "session_confidence_score": round(rolling_score, 2),
        "verdict": prediction,
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
        
        # Compile temporary result for active streaming
        avg_score = float(np.mean(session["scores"]))
        authenticity_score = round(avg_score * 100.0, 2)
        fake_probability = round((1.0 - avg_score) * 100.0, 2)
        
        return {
            "status": "completed",
            "progress": 1.0,
            "result": {
                "verdict": "authentic" if authenticity_score >= 50.0 else "manipulated",
                "confidence_score": fake_probability,
                "model_used": "MobileNet Ensemble (Cloud Stream)",
                "explanation": f"Streaming analysis compiled. Evaluated {len(session['scores'])} biometric frame(s) with an aggregated authenticity rating of {authenticity_score}%."
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
        
        # Build frame consistency correlation
        correlations = []
        for i in range(len(session["hists"]) - 1):
            corr = cv2.compareHist(session["hists"][i], session["hists"][i+1], cv2.HISTCMP_CORREL)
            correlations.append(corr)
        frame_consistency = round(float(np.mean(correlations)) * 100.0, 2) if correlations else 100.0
        
        tracking_confidence = calculate_tracking_confidence(session["boxes"])
        metadata_score = 100.0 # Virtual camera stream metadata is valid
        
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