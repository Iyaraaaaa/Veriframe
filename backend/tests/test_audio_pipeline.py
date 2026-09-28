import unittest
import numpy as np
import wave
import tempfile
import os
import sys
from unittest.mock import MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from pipelines.audio_pipeline import AudioPipeline
from services.reality_defender_service import RealityDefenderService


class TestAudioPipeline(unittest.TestCase):
    def setUp(self):
        self.mock_rd = MagicMock(spec=RealityDefenderService)
        self.mock_rd.detector = MagicMock()
        self.mock_rd.detector.is_configured.return_value = False

        self.pipeline = AudioPipeline(rd_service=self.mock_rd)
        self.temp_files = []

    def tearDown(self):
        for path in self.temp_files:
            if os.path.exists(path):
                try:
                    os.remove(path)
                except Exception:
                    pass

    def _create_wav(self, samples: np.ndarray, sample_rate: int = 16000) -> str:
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp.close()
        self.temp_files.append(tmp.name)

        int_samples = (samples * 32767).astype(np.int16)
        with wave.open(tmp.name, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(int_samples.tobytes())
        return tmp.name

    def test_audio_pipeline_rd_disabled_inputs(self):
        sample_rate = 16000
        duration = 1.5
        t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)

        # 1. Digital silence
        silence_samples = np.zeros(len(t), dtype=np.float32)
        silence_wav = self._create_wav(silence_samples, sample_rate)

        # 2. 440 Hz pure tone
        tone_samples = 0.5 * np.sin(2 * np.pi * 440 * t).astype(np.float32)
        tone_wav = self._create_wav(tone_samples, sample_rate)

        # 3. White noise
        rng = np.random.default_rng(seed=123)
        noise_samples = rng.uniform(-0.4, 0.4, size=len(t)).astype(np.float32)
        noise_wav = self._create_wav(noise_samples, sample_rate)

        removed_evidence_str = "Synthetic neural speech markers / cloned voice signatures identified."

        for name, wav_path in [("Silence", silence_wav), ("Tone_440Hz", tone_wav), ("White_Noise", noise_wav)]:
            with self.subTest(audio_type=name):
                res = self.pipeline.process(wav_path, source="Test")
                
                # Assert none returns MANIPULATED or HIGH risk level
                self.assertNotEqual(res["verdict"], "MANIPULATED", f"{name} returned MANIPULATED verdict")
                self.assertNotEqual(res["riskLevel"], "HIGH", f"{name} returned HIGH risk level")

                # Assert none contains the removed hardcoded evidence string
                self.assertNotIn(removed_evidence_str, res["detectedEvidence"], f"{name} contained removed evidence string")

                # Assert engines_used has acoustic_heuristics and message present
                self.assertEqual(res["engines_used"], ["acoustic_heuristics"])
                self.assertTrue(res["degraded"])
                self.assertIn("Audio deep model is unavailable; local-only result.", res["forensicObservations"])


if __name__ == "__main__":
    unittest.main()
