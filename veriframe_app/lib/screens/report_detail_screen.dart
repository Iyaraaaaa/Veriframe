import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veriframe_app/models/report_model.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class ReportDetailPage extends StatefulWidget {
  final ReportModel report;
  const ReportDetailPage({Key? key, required this.report}) : super(key: key);

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  bool _generating = false;

  Future<void> _openPdf() async {
    setState(() => _generating = true);
    final file = await PdfService.instance.generateReportPdf(
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
    if (file != null && await file.exists()) {
      await OpenFilex.open(file.path);
    }
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);
    final r = widget.report;
    final isReal = r.prediction == 'REAL';

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.videoName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isReal ? VFColors.emerald600 : VFColors.red600)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isReal ? 'REAL' : 'FAKE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isReal ? VFColors.emerald600 : VFColors.red600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Score: ${r.score.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: text),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(r.createdAt)}',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const Divider(height: 32),
            Text(
              'Verdict: ${r.prediction}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${r.confidence.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 14, color: muted),
            ),
            const SizedBox(height: 8),
            Text(
              'Reasoning:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
            const SizedBox(height: 4),
            Text(r.reasoning, style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _openPdf,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _generating ? 'Generating PDF...' : 'Open PDF Report',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
