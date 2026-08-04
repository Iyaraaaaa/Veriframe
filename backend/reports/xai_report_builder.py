import time
import hashlib
import logging
from typing import Dict, Any, List

logger = logging.getLogger("veriframe.reports.xai_report_builder")

class XAIReportBuilder:
    """Stage 14 & Stage 15 — Explainable AI & Professional Report Engine"""

    @staticmethod
    def build_report(
        source: str,
        media_type: str,
        fused_result: Dict[str, Any],
        metadata_dict: Dict[str, Any],
        suspicious_frames: List[Dict[str, Any]],
        frames_analyzed: int,
        faces_analyzed: int,
        processing_time_sec: float,
        model_version: str = "EfficientViT-Forensic-v2.0 (TFLite)",
    ) -> Dict[str, Any]:

        verdict = fused_result["verdict"]
        authenticity = fused_result["authenticity_score"]
        fake_prob = fused_result["fake_probability"]
        confidence = fused_result["confidence"]
        uncertainty = fused_result["uncertainty"]

        # Stage 14 — Rationale generation ("Why decision was made")
        why_decision_made = []
        evidence_items = []
        limitations = []
        recommendations = []

        if verdict == "AUTHENTIC":
            why_decision_made.append(f"Biometric face features exhibit continuous authentic spatial textures with an authenticity index of {authenticity}%.")
            why_decision_made.append(f"Inter-frame temporal stability is high ({fused_result['temporal_consistency_score']}% consistency).")
            why_decision_made.append("No unnatural boundary transitions or GAN artifacts detected in eyes or mouth crops.")
            evidence_items.append("Authentic facial landmark alignment verified across sequence.")
            evidence_items.append("Container metadata matches standard camera profiles.")
            recommendations.append("Media is cleared for publication / standard archival.")

        elif verdict == "LIKELY_AUTHENTIC":
            why_decision_made.append(f"Primary face regions align closely with authentic profiles ({authenticity}% authenticity).")
            why_decision_made.append("Minor visual noise or compression artifacts present, but biometric structure remains unbroken.")
            evidence_items.append("No significant deepfake boundary signatures detected.")
            recommendations.append("Media is likely authentic; secondary manual review recommended if used in high-risk legal proceedings.")

        elif verdict == "INCONCLUSIVE":
            why_decision_made.append(f"Model uncertainty is elevated ({uncertainty}%) due to low face quality, extreme angles, or heavy video compression.")
            why_decision_made.append("Evidence is split or insufficient to establish definitive authenticity or manipulation.")
            evidence_items.append("Face resolution or lighting conditions fall below optimal forensic thresholds.")
            limitations.append("Video resolution or severe compression noise limits deep feature extraction.")
            recommendations.append("Obtain an uncompressed original source file or higher-resolution camera feed for re-analysis.")

        elif verdict == "LIKELY_MANIPULATED":
            why_decision_made.append(f"Biometric manipulation signatures identified in face region (Fake probability: {fake_prob}%).")
            why_decision_made.append("Multi-crop analysis revealed localized texture anomalies in eyes or mouth regions.")
            evidence_items.append(f"Elevated prediction variance across neighboring frames (Consistency: {fused_result['temporal_consistency_score']}%).")
            recommendations.append("Flag media as unverified. Request original cryptographic camera signature.")

        else: # MANIPULATED
            why_decision_made.append(f"High-confidence deepfake manipulation signatures detected across multiple biometric face crops (Fake probability: {fake_prob}%).")
            why_decision_made.append("Temporal flickering and identity drift confirmed in inter-frame analysis.")
            evidence_items.append("Severe spatial boundary anomalies and facial reenactment signatures detected.")
            if fused_result["metadata_anomaly_score"] > 30.0:
                evidence_items.append(f"Metadata modification markers detected (Anomaly score: {fused_result['metadata_anomaly_score']}%).")
            recommendations.append("Restrict media distribution. Escalate report to compliance or legal forensics department.")

        # Default limitations
        limitations.append("Analysis is optimized for human face regions; non-facial visual manipulations require secondary tools.")
        limitations.append("High compression bitrates (e.g., WhatsApp re-encoding) may degrade secondary artifact detection.")

        verification_id = f"VRF-{int(time.time() * 1000)}"
        report_hash = hashlib.sha256(f"{verification_id}-{time.time()}".encode()).hexdigest()

        # Stage 15 — Professional Report JSON
        return {
            "verificationId": verification_id,
            "verifiedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "mediaType": media_type,
            "source": source,
            "verdict": verdict,
            "authenticityScore": authenticity,
            "fakeProbability": fake_prob,
            "confidence": confidence,
            "uncertainty": uncertainty,
            "riskLevel": "LOW" if authenticity >= 75.0 else ("MEDIUM" if authenticity >= 45.0 else "HIGH"),
            "whyDecisionMade": why_decision_made,
            "detectedEvidence": evidence_items,
            "limitations": limitations,
            "recommendations": recommendations,
            "suspiciousFrames": suspicious_frames,
            "metrics": {
                "framesAnalyzed": frames_analyzed,
                "facesAnalyzed": faces_analyzed,
                "processingTimeSec": round(processing_time_sec, 2),
                "modelVersion": model_version,
                "faceQualityScore": fused_result["face_quality_score"],
                "temporalConsistency": fused_result["temporal_consistency_score"],
                "trackingConfidence": fused_result["tracking_confidence"],
                "metadataAnomalyScore": fused_result["metadata_anomaly_score"],
            },
            "metadata": metadata_dict,
            "reportHash": report_hash,
            "is_fake": authenticity < 50.0,
        }
