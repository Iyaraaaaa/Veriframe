import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veriframe_app/models/report_model.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ReportDetailPage extends StatefulWidget {
  final ReportModel report;

  const ReportDetailPage({super.key, required this.report});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  bool _isProcessingPdf = false;

  Future<void> _openPdfReport() async {
    setState(() => _isProcessingPdf = true);

    try {
      // 1. Storage Permission check for Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            _showPermissionDeniedDialog();
            setState(() => _isProcessingPdf = false);
            return;
          }
        }
      }

      // 2. Resolve PDF path
      // Construct target download/local path based on standard name if path is missing/invalid
      final formattedDate = DateFormat('yyyy-MM-dd_HH-mm').format(widget.report.createdAt);
      final pdfName = 'Verification_Report_$formattedDate.pdf';
      
      String targetPath = widget.report.pdfPath;
      if (targetPath.isEmpty) {
        if (Platform.isAndroid) {
          targetPath = '/storage/emulated/0/Download/VeriFrame/$pdfName';
        } else {
          final appDocDir = await getApplicationDocumentsDirectory();
          targetPath = '${appDocDir.path}/VeriFrame/$pdfName';
        }
      }

      File pdfFile = File(targetPath);

      // 3. Re-generate / Re-download if not exists
      if (!await pdfFile.exists()) {
        final regenerated = await PdfService.instance.generateReportPdf(
          reportId: widget.report.reportId,
          videoName: widget.report.videoName,
          prediction: widget.report.prediction,
          confidence: widget.report.confidence,
          score: widget.report.score,
          reasoning: widget.report.reasoning,
          createdAt: widget.report.createdAt,
          duration: widget.report.duration,
          processingTime: widget.report.processingTime,
        );

        if (regenerated != null && await regenerated.exists()) {
          pdfFile = regenerated;
        } else {
          throw Exception("Could not find or regenerate PDF report.");
        }
      }

      // 4. Open file
      final openResult = await OpenFilex.open(pdfFile.path);
      if (openResult.type != ResultType.done) {
        throw Exception(openResult.message);
      }
    } catch (e) {
      debugPrint('[ReportDetailPage] Open PDF Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error opening PDF: ${e.toString()}"),
            backgroundColor: VFColors.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPdf = false);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF0F1523),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: VFColors.red600),
            const SizedBox(width: 8),
            const Text("Permission Denied", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Storage permission is required to save and open forensic PDF reports on your device.",
          style: TextStyle(color: Color(0xFFE8F0FF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: VFColors.blue600),
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = VFColors.adaptiveCard(isDark);
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);
    
    final isReal = widget.report.prediction == 'REAL';
    final severityColor = isReal ? VFColors.emerald600 : VFColors.red600;

    return MainScaffold(
      showBack: true,
      title: const Text('Report Analysis Details'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card (Verdict Badge)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isReal ? Icons.verified : Icons.warning_amber_rounded,
                      color: severityColor,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isReal ? "Authentic Video" : "Manipulated (Deepfake) Video",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Authenticity Score: ${widget.report.score.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: severityColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Model Confidence: ${widget.report.confidence.toStringAsFixed(1)}%",
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metadata Detail Table
            Text(
              "Media Details",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
              ),
              child: Column(
                children: [
                  _buildDetailRow("File Name", widget.report.videoName, text, muted),
                  const Divider(),
                  _buildDetailRow("Scan Time", DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.report.createdAt), text, muted),
                  const Divider(),
                  _buildDetailRow("Processing Duration", "${widget.report.processingTime.toStringAsFixed(1)}s", text, muted),
                  const Divider(),
                  _buildDetailRow("Report ID", widget.report.reportId, text, muted),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reasoning Section
            Text(
              "Forensic Report Reasoning",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: text),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
              ),
              child: Text(
                widget.report.reasoning.isNotEmpty
                    ? widget.report.reasoning
                    : "No forensic reasoning compiled.",
                style: TextStyle(fontSize: 13, height: 1.5, color: text),
              ),
            ),
            const SizedBox(height: 32),

            // Download/Open PDF Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessingPdf ? null : _openPdfReport,
                icon: _isProcessingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _isProcessingPdf ? "Processing Report..." : "Open PDF Report",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VFColors.blue600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
