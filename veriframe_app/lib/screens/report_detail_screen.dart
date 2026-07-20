import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:veriframe_app/utils/theme.dart';

class ReportDetailPage extends StatefulWidget {
  final VerificationResult report;
  const ReportDetailPage({super.key, required this.report});

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

    final verdictColor = isReal ? VFColors.emerald600 : VFColors.red600;
    final riskColor = r.riskLevel == 'LOW'
        ? VFColors.emerald600
        : (r.riskLevel == 'MEDIUM' ? VFColors.amber600 : VFColors.red600);

    return Scaffold(
      backgroundColor: VFColors.adaptiveBg(isDark),
      appBar: AppBar(
        title: const Text('Forensic Report Analysis'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: text,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VFColors.adaptiveCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? VFColors.gray800 : VFColors.gray200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: verdictColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isReal ? Icons.verified_user_rounded : Icons.gavel_rounded,
                          color: verdictColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          r.mediaName ?? 'Forensic Media Scan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    r.mediaPath ?? 'Stream session source',
                    style: TextStyle(fontSize: 12, color: muted, fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderMeta('VERDICT', r.verdict, verdictColor),
                      _buildHeaderMeta('RISK LEVEL', r.riskLevel, riskColor),
                      _buildHeaderMeta('SOURCE', r.source.toUpperCase(), text),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Authenticity circular progress card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: VFColors.adaptiveCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? VFColors.gray800 : VFColors.gray200,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'FORENSIC CONCLUSION CONFIDENCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: r.authenticityScore / 100,
                          strokeWidth: 10,
                          backgroundColor: isDark ? VFColors.gray800 : VFColors.gray100,
                          valueColor: AlwaysStoppedAnimation(verdictColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${r.authenticityScore.toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                          ),
                          Text(
                            isReal ? 'AUTHENTIC' : 'MANIPULATED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: verdictColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildProgressDetailRow(
                    'Fusion Confidence Rating',
                    r.confidence,
                    isDark ? VFColors.gray800 : VFColors.gray100,
                    VFColors.blue600,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Forensic details subscores checklist
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VFColors.adaptiveCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? VFColors.gray800 : VFColors.gray200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DETAILED PIPELINE METRICS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: muted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildForensicProgressBar('Frame Color Consistency', r.frameConsistency, verdictColor, isDark),
                  const SizedBox(height: 16),
                  _buildForensicProgressBar('Biometric Face Tracking', r.trackingConfidence, verdictColor, isDark),
                  const SizedBox(height: 16),
                  _buildForensicProgressBar('Metadata Header Integrity', r.metadataScore, VFColors.blue600, isDark),
                  if (r.ocrConfidence > 0) ...[
                    const SizedBox(height: 16),
                    _buildForensicProgressBar('OCR Overlay Text Confidence', r.ocrConfidence, VFColors.blue600, isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Evidence and Logs Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VFColors.adaptiveCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? VFColors.gray800 : VFColors.gray200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verification Signature Details
                  Text(
                    'VERIFICATION KEY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: muted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMetaTextRow('Scan ID', r.verificationId, text),
                  _buildMetaTextRow('Scan Date', DateFormat('yyyy-MM-dd HH:mm:ss').format(r.verifiedAt), text),
                  _buildMetaTextRow('SHA-256 Hash', r.reportHash, text, isMono: true),
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Detected anomalies list
                  if (r.detectedEvidence.isNotEmpty) ...[
                    Text(
                      'DETECTED ANOMALIES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: VFColors.red600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...r.detectedEvidence.map((ev) => _buildObservationTile(ev, VFColors.red600, isDark)),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                  ],

                  // Forensic log list
                  Text(
                    'FORENSIC OBSERVATIONS LOG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: muted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...r.forensicObservations.map((obs) => _buildObservationTile(obs, VFColors.blue600, isDark)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Elevated Forensic PDF Download button
            ElevatedButton.icon(
              onPressed: _generating ? null : _openPdf,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                _generating ? 'Compiling PDF...' : 'Open Forensic PDF Report',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VFColors.blue600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMeta(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDetailRow(String title, double score, Color bg, Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              "${score.toStringAsFixed(1)}%",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: activeColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 6,
            backgroundColor: bg,
            valueColor: AlwaysStoppedAnimation(activeColor),
          ),
        ),
      ],
    );
  }

  Widget _buildForensicProgressBar(String title, double score, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
            ),
            Text(
              "${score.toStringAsFixed(1)}%",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 5,
            backgroundColor: isDark ? VFColors.gray800 : VFColors.gray100,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaTextRow(String label, String value, Color text, {bool isMono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: text,
                fontWeight: FontWeight.bold,
                fontFamily: isMono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationTile(String text, Color iconColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.12) : VFColors.gray50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 6, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
