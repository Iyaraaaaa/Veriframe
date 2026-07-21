# VeriFrame
AI-Powered Media Forensics Platform

## Pipeline Architecture

### Video Link Verification
```
Video Link
    ↓
Stream Download (extract frames while downloading)
    ↓
Adaptive Frame Sampling (20-40 high-quality frames)
    ↓
Face Detection (MTCNN -> MediaPipe -> Haar Cascade)
    ↓
Face Quality Filter (blur, brightness, size, occlusion)
    ↓
Multi-face Handling (track each face, weight by quality)
    ↓
TFLite Inference (parallel batch processing)
    ↓
Temporal Smoothing (median, moving average, confidence smoothing)
    ↓
Confidence Calibration (Temperature + Platt Scaling)
    ↓
Adaptive Decision (Real / Likely Real / Uncertain / Likely Fake / Fake)
    ↓
Forensic Report
```

### Live Stream Verification
```
Live Stream
    ↓
Receive Frames
    ↓
Face Detection
    ↓
Quality Filter
    ↓
TFLite Inference (every 300-500ms)
    ↓
Rolling Window (last 30 frames)
    ↓
Temporal Smoothing
    ↓
Continuous Prediction Update
```

### Offline (On-Device)
```
Local Video
    ↓
Adaptive Thumbnail Extraction
    ↓
Quality Filtering
    ↓
TFLite Batch Inference
    ↓
Confidence Smoothing
    ↓
Result (no Flutter UI changes)
```

## Backend Modules

| Module | Purpose |
|--------|---------|
| `config.py` | Centralized configuration constants |
| `detectors/face_detector.py` | MTCNN + MediaPipe + Haar Cascade fallback |
| `filters/frame_sampler.py` | Adaptive frame sampling (beginning, middle, end, scene changes, motion peaks) |
| `filters/quality_filter.py` | Blur, brightness, size, and occlusion filtering |
| `calibration/temporal_filter.py` | Median, moving average, temporal voting |
| `calibration/confidence_calibration.py` | Temperature Scaling and Platt Scaling |
| `pipelines/video_pipeline.py` | End-to-end video verification pipeline |
| `pipelines/stream_pipeline.py` | Live stream verification with rolling window |
| `pipelines/offline_pipeline.py` | On-device offline pipeline |
| `metrics/evaluator.py` | ROC, AUC, Precision, Recall, F1, Confusion Matrix |
| `training/trainer.py` | Dataset loaders and training config |

## API Endpoints (Backward Compatible)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| POST | `/predict` | Upload and verify local video |
| POST | `/verify/link` | Start async video link verification |
| POST | `/verify/stream` | Start live stream session |
| POST | `/analyze/stream/frame` | Analyze stream frame (base64) |
| GET | `/analysis/{id}` | Poll job/stream status |
| POST | `/report/create` | Generate forensic report |

### Response Format

All responses maintain the existing JSON structure:

```json
{
  "verificationId": "VRF-...",
  "verifiedAt": "2024-01-01T00:00:00Z",
  "mediaType": "video/mp4",
  "source": "Local Upload",
  "authenticityScore": 85.5,
  "fakeProbability": 14.5,
  "confidence": 82.3,
  "metadataScore": 100.0,
  "frameConsistency": 90.2,
  "ocrConfidence": 0.0,
  "trackingConfidence": 88.5,
  "manipulationScore": 14.5,
  "verdict": "AUTHENTIC",
  "riskLevel": "LOW",
  "detectedEvidence": ["..."],
  "forensicObservations": ["..."],
  "reportHash": "..."
}
```

## Training Guide

### Supported Datasets

- DFDC (Deepfake Detection Challenge)
- FaceForensics++
- Celeb-DF v2
- DeeperForensics
- Google DeepFakeDetection

### Dataset Preparation

1. Organize frames into `real/` and `fake/` directories
2. Ensure consistent face crops (224x224)
3. Apply class balancing to handle dataset imbalance

### Training Improvements

- **Augmentation**: Random JPEG compression, blur, noise, brightness, gamma, color jitter, random crop/resize
- **Regularization**: MixUp, CutMix, label smoothing, early stopping
- **Optimization**: Cosine LR schedule, focal loss, mixed precision
- **Export**: SavedModel, TFLite FP16, TFLite INT8

### Run Training

```bash
cd backend
python -m training.trainer
```

## Model Export

```bash
# Export to SavedModel
python -m training.export --format saved_model

# Export to TFLite FP16
python -m training.export --format tflite_fp16

# Export to TFLite INT8
python -m training.export --format tflite_int8
```

## Evaluation Metrics

Generate comprehensive evaluation reports:

```bash
python -m metrics.evaluator --model veriframe_model.tflite --dataset test/
```

Reports include:
- ROC Curve
- AUC Score
- Precision / Recall / F1
- Confusion Matrix
- False Positive Rate
- False Negative Rate

## Running the Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

## Benchmark Results

| Metric | Value |
|--------|-------|
| ROC-AUC | 0.9768 |
| Accuracy | 91% |
| F1-Score | 0.91 |
| False Negative Rate | 4.8% |
| False Positive Rate | 13.1% |

## Performance

- Parallelized frame extraction, face detection, and inference
- Rolling window for live streams (no per-frame classification)
- Adaptive frame sampling reduces processing time
- Confidence calibration stabilizes predictions
