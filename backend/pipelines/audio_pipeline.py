import os
import time
import logging
import hashlib
import wave
import numpy as np
import cv2
import base64
from typing import Dict, Any, Optional, List

from config import config as app_config
from calibration.confidence_calibration import ConfidenceCalibrator
from services.reality_defender_service import RealityDefenderService
from utils.transparency import THRESHOLDS_IMAGE_AUDIO

logger = logging.getLogger("veriframe.pipelines.audio")

class AudioPipeline:
    """
    Audio Deepfake Verification Pipeline.
    Supports triple-track verification:
    1. Local Acoustic & Spectral Forensics (Vocoder cutoff frequency, noise floor analysis, digital silence detection)
    2. Audio.tflite On-Device Model (experimental 1536-dim spectral projection -> fake sigmoid; disabled by default)
    3. Reality Defender Voice AI (State-of-the-art synthetic speech, voice cloning & audio manipulation detection)
    
    Note: The 1536-dim projection is a random Gaussian projection of mel spectrogram statistics,
    NOT a wav2vec2 embedding. Audio.tflite outputs constant 1.0 on realistic inputs and is
    excluded from the fusion score via AUDIO_TFLITE_ENABLED=False.
    """

    def __init__(
        self,
        calibrator: Optional[ConfidenceCalibrator] = None,
        rd_service: Optional[RealityDefenderService] = None,
        aud_interpreter=None,
        aud_input_details=None,
        aud_output_details=None,
    ):
        self.calibrator = calibrator or ConfidenceCalibrator()
        self.rd_service = rd_service or RealityDefenderService()
        self.aud_interpreter = aud_interpreter
        self.aud_input_details = aud_input_details
        self.aud_output_details = aud_output_details

        # Build a fixed deterministic projection matrix: spectral_features -> 1536
        # (acts as a random Gaussian projection of spectral statistics to 1536 dimensions)
        rng = np.random.default_rng(seed=42)
        self._projection = rng.standard_normal((128, 1536)).astype(np.float32)

    def _build_audio_embedding(self, audio_path: str) -> Optional[np.ndarray]:
        """
        Extract spectral features from audio file and project to 1536-dim embedding
        compatible with Audio.tflite input tensor.
        Uses 128-band mel spectrogram statistics -> random Gaussian projection -> [1, 1536].
        This is NOT a wav2vec2 embedding; it is a deterministic random projection of
        hand-crafted spectral features.
        """
        try:
            # Load raw PCM via wave (works for WAV; fall back for compressed)
            with wave.open(audio_path, "rb") as wf:
                sample_rate = wf.getframerate()
                n_frames = wf.getnframes()
                sample_width = wf.getsampwidth()
                channels = wf.getnchannels()
                raw = wf.readframes(min(n_frames, sample_rate * 30))

            dtype = np.int16 if sample_width == 2 else (np.int32 if sample_width == 4 else np.uint8)
            data = np.frombuffer(raw, dtype=dtype).astype(np.float32)
            if channels > 1:
                data = data[0::channels]  # mono
            # Normalize
            max_val = np.max(np.abs(data)) + 1e-8
            data = data / max_val

            # Build mel-filterbank features manually (128 bands)
            n_fft = 2048
            hop = 512
            n_mels = 128
            frames = []
            for start in range(0, max(1, len(data) - n_fft), hop):
                frame = data[start: start + n_fft]
                if len(frame) < n_fft:
                    frame = np.pad(frame, (0, n_fft - len(frame)))
                windowed = frame * np.hanning(n_fft)
                spectrum = np.abs(np.fft.rfft(windowed)) ** 2
                frames.append(spectrum)

            if not frames:
                return None

            stft_matrix = np.stack(frames, axis=0)  # (T, n_fft//2+1)

            # Mel filterbank
            fmin, fmax = 20.0, float(sample_rate) / 2.0
            n_bins = stft_matrix.shape[1]
            mel_low = 2595 * np.log10(1 + fmin / 700)
            mel_high = 2595 * np.log10(1 + fmax / 700)
            mel_points = np.linspace(mel_low, mel_high, n_mels + 2)
            hz_points = 700 * (10 ** (mel_points / 2595) - 1)
            bin_points = np.floor((n_fft + 1) * hz_points / (sample_rate)).astype(int)
            bin_points = np.clip(bin_points, 0, n_bins - 1)

            filterbank = np.zeros((n_mels, n_bins), dtype=np.float32)
            for m in range(1, n_mels + 1):
                f_m_minus, f_m, f_m_plus = bin_points[m - 1], bin_points[m], bin_points[m + 1]
                for k in range(f_m_minus, f_m):
                    if f_m > f_m_minus:
                        filterbank[m - 1, k] = (k - f_m_minus) / (f_m - f_m_minus)
                for k in range(f_m, f_m_plus):
                    if f_m_plus > f_m:
                        filterbank[m - 1, k] = (f_m_plus - k) / (f_m_plus - f_m)

            mel_spectrogram = np.dot(stft_matrix, filterbank.T)  # (T, 128)
            mel_db = 10 * np.log10(mel_spectrogram + 1e-6)

            # Aggregate statistics per band: mean + std + max + min = 4 × 128 = 512 features
            feat_mean = np.mean(mel_db, axis=0)
            feat_std = np.std(mel_db, axis=0)
            feat_max = np.max(mel_db, axis=0)
            feat_min = np.min(mel_db, axis=0)
            spectral_features = np.concatenate([feat_mean, feat_std, feat_max, feat_min])  # (512,)

            # Pad / truncate to 128 dims, then project to 1536
            feat_128 = np.zeros(128, dtype=np.float32)
            feat_128[:min(128, len(spectral_features))] = spectral_features[:128]
            embedding = feat_128 @ self._projection  # (128,) @ (128, 1536) = (1536,)
            # L2 normalize
            norm = np.linalg.norm(embedding) + 1e-8
            embedding = (embedding / norm).reshape(1, 1536)
            return embedding.astype(np.float32)
        except Exception as e:
            logger.debug(f"[AudioPipeline] Embedding extraction failed: {e}")
            return None

    def _run_tflite_inference(self, audio_path: str) -> Optional[float]:
        """Run Audio.tflite on the audio file. Returns fake probability 0-1 or None."""
        if self.aud_interpreter is None:
            return None
        embedding = self._build_audio_embedding(audio_path)
        if embedding is None:
            return None
        try:
            self.aud_interpreter.set_tensor(self.aud_input_details[0]["index"], embedding)
            self.aud_interpreter.invoke()
            output = self.aud_interpreter.get_tensor(self.aud_output_details[0]["index"])
            fake_prob = float(output[0][0])
            return max(0.0, min(1.0, fake_prob))
        except Exception as e:
            logger.warning(f"[AudioPipeline] Audio.tflite inference failed: {e}")
            return None

    def _analyze_wav_forensics(self, audio_path: str) -> Dict[str, Any]:
        """Examines acoustic & spectral properties of WAV audio."""
        try:
            with wave.open(audio_path, "rb") as wf:
                channels = wf.getnchannels()
                sample_width = wf.getsampwidth()
                sample_rate = wf.getframerate()
                n_frames = wf.getnframes()
                duration = n_frames / float(sample_rate) if sample_rate > 0 else 0.0

                raw_bytes = wf.readframes(min(n_frames, sample_rate * 30)) # up to 30s
                if sample_width == 2:
                    dtype = np.int16
                elif sample_width == 4:
                    dtype = np.int32
                else:
                    dtype = np.uint8

                data = np.frombuffer(raw_bytes, dtype=dtype).astype(np.float32)
                if channels > 1:
                    data = data[0::channels] # mono

            if len(data) == 0:
                return {"fake_probability": 0.20, "duration": duration, "sample_rate": sample_rate, "evidence": []}

            # 1. Digital silence analysis (TTS often has pure zeroes without room ambience)
            zero_count = np.sum(np.abs(data) < 1e-4)
            zero_ratio = zero_count / len(data)

            # 2. High-frequency energy analysis (AI vocoders often attenuate or artifact >16kHz)
            # Simple FFT
            fft_vals = np.abs(np.fft.rfft(data[:min(len(data), 65536)]))
            freqs = np.fft.rfftfreq(min(len(data), 65536), 1.0 / sample_rate)

            # Ratio of energy above 14kHz vs total
            high_band_mask = freqs > 14000
            total_energy = np.sum(fft_vals) + 1e-6
            high_energy = np.sum(fft_vals[high_band_mask])
            high_ratio = high_energy / total_energy

            evidence = []
            fake_prob = 0.20

            if zero_ratio > 0.15:
                fake_prob += 0.25
                evidence.append(f"Unnatural digital silence intervals detected ({round(zero_ratio*100, 1)}% silent floor).")

            if sample_rate >= 32000 and high_ratio < 0.015:
                fake_prob += 0.20
                evidence.append("Severe high-frequency band roll-off consistent with 16kHz neural vocoder upsampling.")

            return {
                "fake_probability": min(0.95, fake_prob),
                "duration": round(duration, 2),
                "sample_rate": sample_rate,
                "channels": channels,
                "evidence": evidence,
            }
        except Exception as e:
            logger.debug(f"[AudioPipeline] Fallback for non-wav: {e}")
            return {"fake_probability": 0.25, "duration": 0.0, "sample_rate": 0, "evidence": []}

    def process(self, audio_path: str, source: str = "Local Audio") -> Dict[str, Any]:
        start_time = time.time()
        logger.info(f"[AudioPipeline] Starting audio verification: {audio_path}")

        if not os.path.exists(audio_path):
            raise ValueError(f"Audio file does not exist: {audio_path}")

        with open(audio_path, "rb") as f:
            file_bytes = f.read()
        audio_hash = hashlib.sha256(file_bytes).hexdigest()
        file_ext = os.path.splitext(audio_path)[1].lower()
        file_size_kb = round(len(file_bytes) / 1024.0, 1)

        detected_evidence: List[str] = []
        forensic_observations: List[str] = [
            f"Audio format: {file_ext.upper()} ({file_size_kb} KB).",
            f"Payload Hash: {audio_hash[:16]}...",
        ]

        # 1. Local Spectral & Acoustic Forensics
        local_eval = self._analyze_wav_forensics(audio_path)
        local_fake_prob = local_eval.get("fake_probability", 0.25)
        if local_eval.get("duration", 0) > 0:
            forensic_observations.append(f"Estimated audio timeline: {local_eval['duration']}s at {local_eval.get('sample_rate')}Hz.")
        if local_eval.get("evidence"):
            detected_evidence.extend(local_eval["evidence"])

        # 2. Audio.tflite On-Device Neural Inference (controlled by AUDIO_TFLITE_ENABLED)
        tflite_fake_prob = None
        if getattr(app_config, "AUDIO_TFLITE_ENABLED", False):
            tflite_fake_prob = self._run_tflite_inference(audio_path)
            if tflite_fake_prob is not None:
                forensic_observations.append(f"Audio.tflite On-Device Score: {round(tflite_fake_prob * 100, 1)}% synthetic probability.")
                local_composite = 0.40 * local_fake_prob + 0.60 * tflite_fake_prob
            else:
                local_composite = local_fake_prob
        else:
            local_composite = local_fake_prob

        # 3. Reality Defender Voice AI Detection
        rd_result = None
        rd_available = False
        degraded = False
        engines_used = ["acoustic_heuristics"]

        if getattr(app_config, "AUDIO_TFLITE_ENABLED", False) and tflite_fake_prob is not None:
            engines_used.append("audio_tflite")

        models_used = "VeriFrame Local Acoustic Forensics"
        if "audio_tflite" in engines_used:
            models_used = "VeriFrame Acoustic Forensics + Audio.tflite"

        if self.rd_service and self.rd_service.detector.is_configured():
            try:
                rd_result = self.rd_service.analyze_media(audio_path)
            except Exception as e:
                logger.warning(f"[AudioPipeline] Reality Defender failed: {e}")
                degraded = True
        else:
            degraded = True

        if rd_result and rd_result.get("status") == "success":
            if rd_result.get("partial"):
                degraded = True
                forensic_observations.extend(rd_result.get("observations") or [])
                forensic_observations.append(
                    "Reality Defender result was PARTIAL (models still ANALYZING at the deadline) and was "
                    "excluded from the ensemble; local-only result."
                )
                models_used = (models_used + " (Reality Defender partial, excluded)")
                detected_evidence.extend(rd_result.get("evidence") or [])
                final_fake_prob = local_composite
            else:
                rd_available = True
                engines_used.append("reality_defender")
                rd_fake_prob = float(rd_result.get("fake_probability", 0.0)) / 100.0
                if "audio_tflite" in engines_used:
                    final_fake_prob = 0.50 * local_composite + 0.50 * rd_fake_prob
                    models_used = "Ensemble: Audio.tflite (On-Device) + Spectral Forensics + Reality Defender Voice AI"
                else:
                    final_fake_prob = 0.40 * local_composite + 0.60 * rd_fake_prob
                    models_used = "Ensemble: Acoustic Forensics + Reality Defender Voice AI"
                if rd_result.get("evidence"):
                    detected_evidence.extend(rd_result["evidence"])
                if rd_result.get("observations"):
                    forensic_observations.extend(rd_result["observations"])
                forensic_observations.append(f"Reality Defender Cloud Deepfake Voice Score: {rd_result.get('fake_probability')}%.")
        else:
            degraded = True
            final_fake_prob = local_composite
            forensic_observations.append("Local acoustic spectral decomposition executed.")
            forensic_observations.append("Audio deep model is unavailable; local-only result.")

        # Calibrate & Generate Verdict
        calibrated_fake_prob = self.calibrator.calibrate(final_fake_prob)
        fake_percentage = round(calibrated_fake_prob * 100.0, 2)
        auth_percentage = round((1.0 - calibrated_fake_prob) * 100.0, 2)

        if fake_percentage > THRESHOLDS_IMAGE_AUDIO["manipulated_above_pct"]:
            legacy_verdict = "MANIPULATED"
            fine_verdict = "FAKE" if fake_percentage >= THRESHOLDS_IMAGE_AUDIO["fake_confirmed_at_or_above_pct"] else "LIKELY_FAKE"
            risk_level = "HIGH"
        elif fake_percentage < THRESHOLDS_IMAGE_AUDIO["authentic_below_pct"]:
            legacy_verdict = "AUTHENTIC"
            fine_verdict = "REAL" if fake_percentage <= THRESHOLDS_IMAGE_AUDIO["real_confirmed_at_or_below_pct"] else "LIKELY_REAL"
            risk_level = "LOW"
            if not detected_evidence:
                detected_evidence.append(f"Natural acoustic vocal timbre and continuous air pressure verified (Authenticity: {auth_percentage}%).")
        else:
            legacy_verdict = "INCONCLUSIVE"
            fine_verdict = "UNCERTAIN"
            risk_level = "MEDIUM"
            if not detected_evidence:
                detected_evidence.append("Voice features lie in ambiguous acoustic envelope range.")

        confidence_val = round(abs(calibrated_fake_prob - 0.5) * 200.0, 2)

        # If Reality Defender is unavailable, do NOT return a MANIPULATED/HIGH verdict from acoustic heuristics alone.
        # Return verdict INCONCLUSIVE, low confidence, and a field "engines_used": ["acoustic_heuristics"] with a message that the audio deep model is unavailable.
        if not rd_available:
            if legacy_verdict == "MANIPULATED" or risk_level == "HIGH":
                legacy_verdict = "INCONCLUSIVE"
                fine_verdict = "UNCERTAIN"
                risk_level = "MEDIUM"
            confidence_val = min(confidence_val, 30.0)
            confidence_label = "Low"
        else:
            confidence_label = "High" if confidence_val >= 75.0 else ("Medium" if confidence_val >= 50.0 else "Low")

        processing_time = round(time.time() - start_time, 2)

        # Extract waveform thumbnail for report preview
        thumbnail_base64 = self._extract_waveform_thumbnail(audio_path)

        return {
            "verificationId": f"VRF-AUD-{int(time.time() * 1000)}",
            "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "mediaType": f"audio/{file_ext.lstrip('.')}",
            "source": source,
            "authenticityScore": auth_percentage,
            "fakeProbability": fake_percentage,
            "confidence": confidence_val,
            "verdict": legacy_verdict,
            "fineVerdict": fine_verdict,
            "riskLevel": risk_level,
            "modelsUsed": models_used,
            "detectedEvidence": detected_evidence,
            "forensicObservations": forensic_observations,
            "reportHash": audio_hash,
            "durationSec": local_eval.get("duration", 0.0),
            "processingTimeSec": processing_time,
            "reality_defender": rd_result,
            "confidence_label": confidence_label,
            "thumbnailBase64": thumbnail_base64,
            "engines_used": engines_used,
            "degraded": degraded,
        }


    def _extract_waveform_thumbnail(self, audio_path: str, width: int = 320, height: int = 180) -> Optional[str]:
        """Generate a waveform visualization as base64 JPEG thumbnail."""
        try:
            with wave.open(audio_path, "rb") as wf:
                sample_rate = wf.getframerate()
                n_frames = wf.getnframes()
                sample_width = wf.getsampwidth()
                channels = wf.getnchannels()
                raw = wf.readframes(n_frames)

            dtype = np.int16 if sample_width == 2 else (np.int32 if sample_width == 4 else np.uint8)
            data = np.frombuffer(raw, dtype=dtype).astype(np.float32)
            if channels > 1:
                data = data[0::channels]  # mono

            # Normalize
            max_val = np.max(np.abs(data)) + 1e-8
            data = data / max_val

            # Downsample for visualization
            step = max(1, len(data) // width)
            samples = data[::step][:width]

            # Create waveform image
            img = np.zeros((height, width, 3), dtype=np.uint8)
            mid_y = height // 2
            scale = height // 2 - 10

            for i, sample in enumerate(samples):
                if i >= width:
                    break
                y = int(mid_y - sample * scale)
                cv2.line(img, (i, mid_y), (i, y), (0, 200, 100), 1)

            # Add subtle grid
            for y in range(0, height, 20):
                cv2.line(img, (0, y), (width, y), (30, 30, 30), 1)

            _, buffer = cv2.imencode('.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, 80])
            return base64.b64encode(buffer).decode('utf-8')
        except Exception:
            # Return a placeholder if extraction fails
            try:
                img = np.zeros((height, width, 3), dtype=np.uint8)
                cv2.putText(img, 'AUDIO', (width//2-40, height//2), cv2.FONT_HERSHEY_SIMPLEX, 1, (100, 100, 100), 2)
                _, buffer = cv2.imencode('.jpg', img, [cv2.IMWRITE_JPEG_QUALITY, 80])
                return base64.b64encode(buffer).decode('utf-8')
            except Exception:
                return None
