FROM python:3.11-slim

LABEL maintainer="veriframe"
LABEL description="Veriframe AI Deepfake Detection Backend"

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py ./main.py
COPY config.py ./config.py
COPY detectors/ ./detectors/
COPY filters/ ./filters/
COPY calibration/ ./calibration/
COPY pipelines/ ./pipelines/
COPY preprocessing/ ./preprocessing/
COPY cache/ ./cache/
COPY utils/ ./utils/
COPY database/ ./database/
COPY workers/ ./workers/
COPY reports/ ./reports/
COPY assets/ ./assets/

# Create directories
RUN mkdir -p logs cache

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run with uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]