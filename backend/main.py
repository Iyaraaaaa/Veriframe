from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
import tensorflow as tf
import numpy as np
import cv2
import tempfile
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Load model once at startup, not per-request ----
model_path = "../assets/veriframe_model.tflite"
interpreter = tf.lite.Interpreter(model_path=model_path)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

# Confirmed from model inspection: model expects 224x224 float32 input
INPUT_SIZE = (224, 224)

# Haar cascade for face detection (as fallback)
haar_path = os.path.join(os.path.dirname(cv2.__file__), "data", "haarcascade_frontalface_default.xml")
face_cascade = cv2.CascadeClassifier(haar_path)

# Initialize MTCNN detector for highest accuracy matching the training phase
import torch
try:
    from facenet_pytorch import MTCNN
    # Disable gradient computation for speed and memory efficiency
    torch.set_grad_enabled(False)
    device = torch.device('cuda:0' if torch.cuda.is_available() else 'cpu')
    mtcnn_detector = MTCNN(margin=0, keep_all=False, select_largest=True, device=device)
    print(f"[MTCNN] Initialized successfully on {device}")
except Exception as e:
    print(f"[MTCNN] Failed to initialize: {e}. Falling back to Haar Cascade.")
    mtcnn_detector = None


def extract_faces_from_video(video_path, max_frames=20):
    """Extract face crops from evenly spaced frames in the video."""
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    if total_frames == 0:
        cap.release()
        return []

    frame_indices = np.linspace(0, total_frames - 1, max_frames, dtype=int)

    faces = []
    for idx in frame_indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if not ret:
            continue

        face_crop = None

        # 1. Try modern MTCNN detector first
        if mtcnn_detector is not None:
            try:
                # Convert BGR (cv2 default) to RGB (MTCNN expectation)
                frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                boxes, _ = mtcnn_detector.detect(frame_rgb)
                
                if boxes is not None and len(boxes) > 0:
                    box = boxes[0]  # Take the largest face
                    xmin, ymin, xmax, ymax = [int(b) for b in box]
                    w = xmax - xmin
                    h = ymax - ymin
                    p_h = 0
                    p_w = 0
                    # Standard square padding logic matching training preprocessing
                    if h > w:
                        p_w = int((h-w)/2)
                    elif h < w:
                        p_h = int((w-h)/2)

                    ymin_padded = max(ymin - p_h, 0)
                    ymax_padded = min(ymax + p_h, frame.shape[0])
                    xmin_padded = max(xmin - p_w, 0)
                    xmax_padded = min(xmax + p_w, frame.shape[1])
                    
                    face_crop = frame[ymin_padded:ymax_padded, xmin_padded:xmax_padded]
            except Exception as e:
                print(f"[MTCNN] Inference error: {e}")

        # 2. Fallback to Haar Cascade if MTCNN failed or didn't detect any face
        if face_crop is None or face_crop.size == 0:
            try:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                detected = face_cascade.detectMultiScale(gray, 1.1, 5)
                if len(detected) > 0:
                    x, y, w, h = max(detected, key=lambda box: box[2] * box[3])
                    face_crop = frame[y:y+h, x:x+w]
            except Exception as e:
                print(f"[Haar Cascade] Fallback error: {e}")

        # 3. Resize face to expected input size
        if face_crop is not None and face_crop.size > 0:
            try:
                face_resized = cv2.resize(face_crop, INPUT_SIZE)
                faces.append(face_resized)
            except Exception as e:
                print(f"[Resize] Error: {e}")

    cap.release()
    return faces


def preprocess_face(face_img):
    """
    Normalize a face crop to match model's expected input.

    IMPORTANT: EfficientNetB0 (as used in tf.keras.applications) has its own
    internal rescaling layer and expects RAW pixel values in the 0-255 range,
    NOT normalized 0-1 values. The training pipeline never divided by 255
    (image_dataset_from_directory does not rescale by default), so inference
    must match that exactly. Do NOT divide by 255 here.
    """
    face_img = face_img.astype(np.float32)  # keep 0-255 range, matches training
    face_img = np.expand_dims(face_img, axis=0)
    return face_img


def run_inference(face_img):
    """Run one face crop through the TFLite model, return sigmoid score."""
    interpreter.set_tensor(input_details[0]['index'], face_img)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    return float(output[0][0])


@app.get("/")
def home():
    return {"message": "Veriframe API is running"}


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    # Save uploaded video to a temp file
    suffix = os.path.splitext(file.filename or "")[1]
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await file.read())
        video_path = tmp.name

    try:
        faces = extract_faces_from_video(video_path)

        if len(faces) == 0:
            return {"error": "No faces detected in the video"}

        scores = []
        for face in faces:
            processed = preprocess_face(face)
            score = run_inference(processed)
            scores.append(score)

        avg_score = float(np.mean(scores))

        # Label-inversion fix: sigmoid near 1 = "real" (alphabetical class order: fake=0, real=1)
        prediction = "real" if avg_score >= 0.5 else "fake"
        confidence = avg_score if prediction == "real" else 1 - avg_score

        return {
            "prediction": prediction,
            "confidence": round(confidence, 4),
            "frames_analyzed": len(faces)
        }

    except Exception as e:
        return {"error": f"Failed to process video: {str(e)}"}

    finally:
        if os.path.exists(video_path):
            os.remove(video_path)