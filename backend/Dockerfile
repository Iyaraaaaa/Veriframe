FROM python:3.11-slim

LABEL maintainer="veriframe"
LABEL description="Veriframe AI Deepfake Detection Backend"

WORKDIR /app

# Install system dependencies (including ffmpeg for video stream processing and libgl for OpenCV)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code, model, and assets
COPY . /app/

# Create necessary directories
RUN mkdir -p logs cache

# Render provides the $PORT environment variable (default 10000)
ENV PORT=10000
EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Run with uvicorn on dynamic Render PORT
CMD sh -c "uvicorn main:app --host 0.0.0.0 --port ${PORT:-10000} --workers 1"