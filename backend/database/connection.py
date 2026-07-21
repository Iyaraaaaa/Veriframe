import sqlite3
import os
import json
import time
from typing import Optional, Dict, Any, List
from datetime import datetime
from pathlib import Path
from config import config as app_config

DB_PATH = os.path.join(app_config.CACHE_DIR, "veriframe.db")

def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = get_connection()
    try:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS jobs (
                id TEXT PRIMARY KEY,
                status TEXT NOT NULL DEFAULT 'pending',
                progress REAL DEFAULT 0.0,
                result TEXT,
                error TEXT,
                cached INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS reports (
                id TEXT PRIMARY KEY,
                verification_id TEXT NOT NULL,
                job_id TEXT,
                session_id TEXT,
                source TEXT NOT NULL,
                media_type TEXT,
                authenticity_score REAL,
                fake_probability REAL,
                confidence REAL,
                verdict TEXT,
                risk_level TEXT,
                detected_evidence TEXT,
                forensic_observations TEXT,
                report_hash TEXT UNIQUE,
                frames_analyzed INTEGER DEFAULT 0,
                frames_skipped INTEGER DEFAULT 0,
                processing_time_sec REAL,
                average_score REAL,
                inference_time_ms REAL,
                is_fake INTEGER DEFAULT 0,
                confidence_label TEXT,
                model_used TEXT,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS cache_entries (
                video_hash TEXT PRIMARY KEY,
                result TEXT NOT NULL,
                created_at TEXT NOT NULL,
                last_accessed TEXT NOT NULL,
                access_count INTEGER DEFAULT 1
            );
            CREATE TABLE IF NOT EXISTS analysis_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                verification_id TEXT NOT NULL,
                user_id TEXT,
                source TEXT NOT NULL,
                media_type TEXT,
                verdict TEXT,
                risk_level TEXT,
                authenticity_score REAL,
                confidence REAL,
                report_hash TEXT,
                created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_reports_hash ON reports(report_hash);
            CREATE INDEX IF NOT EXISTS idx_reports_created ON reports(created_at);
            CREATE INDEX IF NOT EXISTS idx_history_verification ON analysis_history(verification_id);
        """)
        conn.commit()
    finally:
        conn.close()

def upsert_job(job_id: str, status: str = "pending", progress: float = 0.0, result: Optional[Dict] = None, error: Optional[str] = None, cached: bool = False):
    now = datetime.utcnow().isoformat()
    conn = get_connection()
    try:
        conn.execute("""
            INSERT INTO jobs (id, status, progress, result, error, cached, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                status=excluded.status,
                progress=excluded.progress,
                result=excluded.result,
                error=excluded.error,
                cached=excluded.cached,
                updated_at=excluded.updated_at
        """, (
            job_id, status, progress,
            json.dumps(result, default=str) if result else None,
            error, 1 if cached else 0, now, now
        ))
        conn.commit()
    finally:
        conn.close()

def insert_report(report: Dict[str, Any]):
    now = datetime.utcnow().isoformat()
    conn = get_connection()
    try:
        conn.execute("""
            INSERT INTO reports (
                id, verification_id, job_id, session_id, source, media_type,
                authenticity_score, fake_probability, confidence, verdict, risk_level,
                detected_evidence, forensic_observations, report_hash,
                frames_analyzed, frames_skipped, processing_time_sec,
                average_score, inference_time_ms, is_fake, confidence_label,
                model_used, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            report.get("verificationId"),
            report.get("verificationId"),
            report.get("_job_id"),
            report.get("_session_id"),
            report.get("source"),
            report.get("mediaType"),
            report.get("authenticityScore"),
            report.get("fakeProbability"),
            report.get("confidence"),
            report.get("verdict"),
            report.get("riskLevel"),
            json.dumps(report.get("detectedEvidence", []), default=str),
            json.dumps(report.get("forensicObservations", []), default=str),
            report.get("reportHash"),
            report.get("framesAnalyzed", 0),
            report.get("framesSkipped", 0),
            report.get("processingTimeSec"),
            report.get("averageScore"),
            report.get("inferenceTimeMs"),
            1 if report.get("is_fake") else 0,
            report.get("confidence_label"),
            report.get("_model_used", "veriframe_model"),
            now,
        ))
        conn.commit()
    finally:
        conn.close()

def get_report_by_hash(report_hash: str) -> Optional[Dict[str, Any]]:
    conn = get_connection()
    try:
        row = conn.execute("SELECT * FROM reports WHERE report_hash = ?", (report_hash,)).fetchone()
        if row:
            return dict(row)
        return None
    finally:
        conn.close()

def list_reports(limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
    conn = get_connection()
    try:
        rows = conn.execute(
            "SELECT * FROM reports ORDER BY created_at DESC LIMIT ? OFFSET ?",
            (limit, offset)
        ).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()

def insert_history(history: Dict[str, Any]):
    now = datetime.utcnow().isoformat()
    conn = get_connection()
    try:
        conn.execute("""
            INSERT INTO analysis_history (
                verification_id, user_id, source, media_type, verdict, risk_level,
                authenticity_score, confidence, report_hash, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            history.get("verificationId"),
            history.get("userId"),
            history.get("source"),
            history.get("mediaType"),
            history.get("verdict"),
            history.get("riskLevel"),
            history.get("authenticityScore"),
            history.get("confidence"),
            history.get("reportHash"),
            now,
        ))
        conn.commit()
    finally:
        conn.close()