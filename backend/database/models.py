from dataclasses import dataclass
from typing import Optional, List
from datetime import datetime

@dataclass
class JobRecord:
    id: str
    status: str
    progress: float
    result: Optional[str]
    error: Optional[str]
    cached: bool
    created_at: str
    updated_at: str

@dataclass
class ReportRecord:
    id: str
    verification_id: str
    job_id: Optional[str]
    session_id: Optional[str]
    source: str
    media_type: Optional[str]
    authenticity_score: Optional[float]
    fake_probability: Optional[float]
    confidence: Optional[float]
    verdict: Optional[str]
    risk_level: Optional[str]
    detected_evidence: Optional[str]
    forensic_observations: Optional[str]
    report_hash: str
    frames_analyzed: int
    frames_skipped: int
    processing_time_sec: Optional[float]
    average_score: Optional[float]
    inference_time_ms: Optional[float]
    is_fake: bool
    confidence_label: Optional[str]
    model_used: str
    created_at: str

@dataclass
class CacheEntry:
    video_hash: str
    result: str
    created_at: str
    last_accessed: str
    access_count: int

@dataclass
class AnalysisHistory:
    id: int
    verification_id: str
    user_id: Optional[str]
    source: str
    media_type: Optional[str]
    verdict: Optional[str]
    risk_level: Optional[str]
    authenticity_score: Optional[float]
    confidence: Optional[float]
    report_hash: Optional[str]
    created_at: str