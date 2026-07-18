import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:veriframe_app/utils/theme.dart';

class ReportDetailPage extends StatefulWidget {
  final VerificationResult report;
  const ReportDetailPage({Key? key, required this.report}) : super(key: key);

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  bool _generating = false;

  Future<void> _openPdf() async {
    setState(() => _generating = true);
    try {
      final file = await PdfService.instance.generateReportPdf(
        result: widget.report,
      );
      if (file != null && await file.exists()) {
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      debugPrint('[ReportDetailPage] PDF open error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening PDF: ${e.toString()}"),
            backgroundColor: VFColors.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);
    final r = widget.report;
    final isReal = r.verdict.toUpperCase() == 'AUTHENTIC';
    
    final accentColor = isReal ? VFColors.emerald600 : VFColors.red600;
    final bgLight = isReal ? VFColors.emerald50 : VFColors.red50;
    final bgDark = isReal ? VFColors.emerald600.withOpacity(0.15) : VFColors.red600.withOpacity(0.15);

    return Scaffold(
      appBar: AppBar(title: const Text('Forensic Report Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Media Path
            Text(
              r.mediaName ?? 'Forensic Verification',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.mediaPath ?? 'Stream source',
              style: TextStyle(fontSize: 12, color: muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? bgDark : bgLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor, width: 1),
                  ),
                  child: Text(
                    r.verdict,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Risk Profile: ${r.riskLevel}',
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold,
                    color: r.riskLevel == 'LOW' ? VFColors.emerald600 : (r.riskLevel == 'MEDIUM' ? VFColors.amber600 : VFColors.red600),
                  ),
                ),
              ],
            ),
            const Divider(height: 36, thickness: 1),

            // Metrics Table
            Text(
              'FORENSIC METRICS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: muted, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),
            _buildMetricTile('Verification ID', r.verificationId, text, muted),
            _buildMetricTile('Verified At', DateFormat('yyyy-MM-dd HH:mm:ss').format(r.verifiedAt), text, muted),
            _buildMetricTile('Authenticity Score', '${r.authenticityScore.toStringAsFixed(2)}%', text, muted, highlight: true, highlightColor: VFColors.emerald600),
            _buildMetricTile('Fake Probability', '${r.fakeProbability.toStringAsFixed(2)}%', text, muted, highlight: true, highlightColor: VFColors.red600),
            _buildMetricTile('Fusion Confidence', '${r.confidence.toStringAsFixed(2)}%', text, muted),
            _buildMetricTile('Frame Consistency', '${r.frameConsistency.toStringAsFixed(2)}%', text, muted),
            _buildMetricTile('Biometric Tracking', '${r.trackingConfidence.toStringAsFixed(2)}%', text, muted),
            _buildMetricTile('Metadata Integrity', '${r.metadataScore.toStringAsFixed(2)}%', text, muted),
            if (r.ocrConfidence > 0)
              _buildMetricTile('OCR Text Overlay', '${r.ocrConfidence.toStringAsFixed(2)}%', text, muted),
            _buildMetricTile('Secure SHA-256 Hash', r.reportHash, text, muted, isMono: true),
            
            const SizedBox(height: 24),
            
            // Evidence & Observations
            if (r.detectedEvidence.isNotEmpty) ...[
              Text(
                'DETECTED EVIDENCE & ANOMALIES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: muted, letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              ...r.detectedEvidence.map((ev) => _buildObservationRow(ev, VFColors.red600, isDark)),
              const SizedBox(height: 24),
            ],

            Text(
              'FORENSIC OBSERVATIONS LOG',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: muted, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),
            ...r.forensicObservations.map((obs) => _buildObservationRow(obs, VFColors.blue600, isDark)),
            
            const SizedBox(height: 32),

            // Open PDF Report Button
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generating ? null : _openPdf,
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    _generating ? 'Compiling Report PDF...' : 'Open Forensic PDF Report',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VFColors.blue600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color text, Color muted, {bool highlight = false, Color? highlightColor, bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontFamily: isMono ? 'monospace' : null,
                color: highlight ? (highlightColor ?? text) : text,
                fontWeight: (highlight || label == 'Verification ID') ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationRow(String text, Color bulletColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: bulletColor, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: VFColors.adaptiveText(isDark),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
