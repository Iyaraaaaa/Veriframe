import os
import logging
import requests
from typing import Dict, Any, Optional
from config import config as app_config

logger = logging.getLogger("veriframe.services.gemini_service")

class GeminiService:
    """
    Google Gemini AI Service for VeriFrame.
    Provides automated forensic report narrative analysis, threat classification,
    and user-facing explanations using Google's Gemini models.
    """

    CANDIDATE_MODELS = [
        "gemini-3.5-flash-lite",
        "gemini-3.5-flash",
        "gemini-flash-latest",
        "gemini-3-flash-preview",
    ]

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key if api_key is not None else app_config.GEMINI_API_KEY
        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models"

    def is_configured(self) -> bool:
        return bool(self.api_key and len(self.api_key.strip()) > 10)

    def generate_forensic_explanation(self, report: Dict[str, Any]) -> Dict[str, Any]:
        """
        Takes a verification report result and generates an AI forensic narrative explanation.
        """
        if not self.is_configured():
            verdict = report.get("verdict", "INCONCLUSIVE")
            fine_verdict = report.get("fineVerdict", verdict)
            fake_prob = report.get("fakeProbability", report.get("manipulationScore", 0.0))
            try:
                fake_val = float(fake_prob)
            except Exception:
                fake_val = 0.0
            return {
                "status": "disabled",
                "narrative": f"Media evaluated as {fine_verdict} ({fake_val}% synthetic probability) using on-device neural models and signal forensics.",
                "threat_assessment": "Standard forensic evaluation. Review technical indicators in report.",
                "ai_summary": f"Media evaluated as {fine_verdict} ({fake_val}% synthetic probability) using on-device neural models and signal forensics.",
                "threat_level": "LOW" if fake_val < 30.0 else ("HIGH" if fake_val > 70.0 else "MEDIUM"),
                "threat_context": "Automated forensic evaluation without external AI narrative.",
                "recommended_action": "Review technical indicators and forensic evidence in report.",
            }


        verdict = report.get("verdict", "INCONCLUSIVE")
        fine_verdict = report.get("fineVerdict", verdict)
        fake_prob = report.get("fakeProbability", report.get("manipulationScore", 0.0))
        auth_score = report.get("authenticityScore", 100.0 - float(fake_prob))
        media_type = report.get("mediaType", "media")
        source = report.get("source", "upload")
        evidence = report.get("detectedEvidence", [])
        observations = report.get("forensicObservations", [])

        prompt = f"""You are VeriFrame's Senior Digital Media Forensic AI Investigator.
Analyze the following deepfake verification technical metrics and provide a concise, authoritative forensic explanation:

Media Type: {media_type}
Source: {source}
Verdict: {verdict} ({fine_verdict})
Deepfake / Manipulation Risk: {fake_prob}%
Authenticity Score: {auth_score}%
Detected Evidence: {', '.join(evidence) if evidence else 'None'}
Forensic Observations: {'; '.join(observations) if observations else 'None'}

Please respond in JSON with the following exact keys:
{{
  "ai_summary": "2-3 sentences explaining the verdict in clear, professional forensic language.",
  "threat_level": "LOW, MEDIUM, HIGH, or CRITICAL",
  "threat_context": "1-2 sentences on the potential danger or deceptive intent (e.g. voice cloning, impersonation, synthetic generation).",
  "recommended_action": "1-2 sentences advising what the user or investigator should do next."
}}
Return ONLY valid JSON without extra markdown formatting.
"""

        for model in self.CANDIDATE_MODELS:
            try:
                url = f"{self.base_url}/{model}:generateContent?key={self.api_key}"
                payload = {
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {
                        "temperature": 0.2,
                        "maxOutputTokens": 500,
                    }
                }
                res = requests.post(url, json=payload, timeout=12)
                if res.status_code == 200:
                    data = res.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                        # Clean markdown json fences if present
                        cleaned = text.strip()
                        if cleaned.startswith("```json"):
                            cleaned = cleaned[7:]
                        if cleaned.startswith("```"):
                            cleaned = cleaned[3:]
                        if cleaned.endswith("```"):
                            cleaned = cleaned[:-3]
                        cleaned = cleaned.strip()

                        import json
                        try:
                            parsed = json.loads(cleaned)
                            return {
                                "status": "success",
                                "model_used": model,
                                "ai_summary": parsed.get("ai_summary", ""),
                                "threat_level": parsed.get("threat_level", "MEDIUM"),
                                "threat_context": parsed.get("threat_context", ""),
                                "recommended_action": parsed.get("recommended_action", ""),
                            }
                        except Exception:
                            return {
                                "status": "success",
                                "model_used": model,
                                "ai_summary": text.strip(),
                                "threat_level": "MEDIUM",
                                "threat_context": "AI generated assessment.",
                                "recommended_action": "Review forensic report metrics.",
                            }
                elif res.status_code in (404, 429, 503):
                    logger.debug(f"[GeminiService] Model {model} returned HTTP {res.status_code}, trying next model.")
                    continue
                else:
                    logger.warning(f"[GeminiService] Model {model} returned HTTP {res.status_code}: {res.text[:150]}")
            except Exception as e:
                logger.debug(f"[GeminiService] Model {model} failed: {e}")
                continue

        return {
            "status": "fallback",
            "narrative": f"Media evaluated as {fine_verdict} ({fake_prob}% synthetic probability) using on-device neural models and signal forensics.",
            "threat_assessment": "Review technical indicators in report.",
        }
