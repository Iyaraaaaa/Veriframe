import json
import hashlib
import time
from typing import Dict, Any, Optional
from datetime import datetime
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas
from io import BytesIO
import cv2
import numpy as np

from database.connection import insert_report, insert_history

class ReportGenerator:
    @staticmethod
    def generate_pdf(report: Dict[str, Any], include_thumbnails: bool = False) -> bytes:
        buffer = BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=72, leftMargin=72, topMargin=72, bottomMargin=18)
        styles = getSampleStyleSheet()
        story = []

        title_style = ParagraphStyle(
            "VeriframeTitle",
            parent=styles["Heading1"],
            fontSize=22,
            textColor=colors.HexColor("#1a1a2e"),
            spaceAfter=12,
        )
        story.append(Paragraph("Veriframe Forensic Report", title_style))
        story.append(Spacer(1, 0.2 * inch))

        meta = [
            ["Verification ID", report.get("verificationId", "N/A")],
            ["Timestamp", report.get("verifiedAt", "N/A")],
            ["Source", report.get("source", "N/A")],
            ["Media Type", report.get("mediaType", "N/A")],
            ["Report Hash", report.get("reportHash", "N/A")[:32] + "..."],
        ]
        meta_table = Table(meta, colWidths=[2.2 * inch, 4 * inch])
        meta_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#16213e")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
            ("ALIGN", (0, 0), (-1, -1), "LEFT"),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, 0), 12),
            ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
            ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#f0f0f0")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("FONTNAME", (0, 1), (0, -1), "Helvetica-Bold"),
            ("FONTSIZE", (0, 1), (-1, -1), 10),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ]))
        story.append(meta_table)
        story.append(Spacer(1, 0.3 * inch))

        verdict_color = colors.green if report.get("verdict") == "AUTHENTIC" else colors.red
        verdict_data = [
            ["Verdict", report.get("verdict", "N/A")],
            ["Risk Level", report.get("riskLevel", "N/A")],
            ["Authenticity Score", f"{report.get('authenticityScore', 0)}%"],
            ["Fake Probability", f"{report.get('fakeProbability', 0)}%"],
            ["Confidence", f"{report.get('confidence', 0)}%"],
            ["Frame Consistency", f"{report.get('frameConsistency', 0)}%"],
            ["Tracking Confidence", f"{report.get('trackingConfidence', 0)}%"],
            ["OCR Confidence", f"{report.get('ocrConfidence', 0)}%"],
            ["Metadata Score", f"{report.get('metadataScore', 0)}%"],
        ]
        verdict_table = Table(verdict_data, colWidths=[2.2 * inch, 4 * inch])
        verdict_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0f3460")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
            ("ALIGN", (0, 0), (-1, -1), "LEFT"),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, 0), 12),
            ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
            ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#f0f0f0")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("FONTNAME", (0, 1), (0, -1), "Helvetica-Bold"),
            ("FONTSIZE", (0, 1), (-1, -1), 10),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ]))
        story.append(Paragraph("Analysis Results", styles["Heading2"]))
        story.append(verdict_table)
        story.append(Spacer(1, 0.3 * inch))

        evidence = report.get("detectedEvidence", [])
        if evidence:
            story.append(Paragraph("Detected Evidence", styles["Heading2"]))
            for item in evidence:
                story.append(Paragraph(f"• {item}", styles["Normal"]))
            story.append(Spacer(1, 0.2 * inch))

        observations = report.get("forensicObservations", [])
        if observations:
            story.append(Paragraph("Forensic Observations", styles["Heading2"]))
            for item in observations:
                story.append(Paragraph(f"• {item}", styles["Normal"]))
            story.append(Spacer(1, 0.2 * inch))

        stats = [
            ["Frames Analyzed", str(report.get("framesAnalyzed", 0))],
            ["Frames Skipped", str(report.get("framesSkipped", 0))],
            ["Processing Time", f"{report.get('processingTimeSec', 0)}s"],
            ["Avg Inference", f"{report.get('inferenceTimeMs', 0)}ms"],
            ["Average Score", f"{report.get('averageScore', 0):.4f}"],
        ]
        stats_table = Table(stats, colWidths=[2.2 * inch, 4 * inch])
        stats_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#533483")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
            ("ALIGN", (0, 0), (-1, -1), "LEFT"),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, 0), 12),
            ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
            ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#f0f0f0")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("FONTNAME", (0, 1), (0, -1), "Helvetica-Bold"),
            ("FONTSIZE", (0, 1), (-1, -1), 10),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ]))
        story.append(Paragraph("Processing Statistics", styles["Heading2"]))
        story.append(stats_table)
        story.append(Spacer(1, 0.3 * inch))

        story.append(Paragraph("Disclaimer", styles["Heading3"]))
        story.append(Paragraph("This report is generated by Veriframe AI for informational purposes only. Results should be verified by qualified forensic analysts before being used in legal or official proceedings.", styles["Normal"]))

        doc.build(story)
        buffer.seek(0)
        return buffer.getvalue()

    @staticmethod
    def save_report_to_db(report: Dict[str, Any], job_id: Optional[str] = None, session_id: Optional[str] = None):
        report["_job_id"] = job_id
        report["_session_id"] = session_id
        report["_model_used"] = "veriframe_model"
        report["_saved_at"] = datetime.utcnow().isoformat()
        insert_report(report)
        insert_history({
            "verificationId": report.get("verificationId"),
            "userId": report.get("userId"),
            "source": report.get("source"),
            "mediaType": report.get("mediaType"),
            "verdict": report.get("verdict"),
            "riskLevel": report.get("riskLevel"),
            "authenticityScore": report.get("authenticityScore"),
            "confidence": report.get("confidence"),
            "reportHash": report.get("reportHash"),
        })