import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  Future<File?> generateReportPdf({
    required String reportId,
    required String videoName,
    required String prediction, // "REAL" or "FAKE"
    required double confidence,
    required double score,
    required String reasoning,
    required DateTime createdAt,
    required double duration,
    required double processingTime,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'VERIFRAME FORENSIC REPORT',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.Text(
                      'ID: $reportId',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 2, color: PdfColors.blue800),
                pw.SizedBox(height: 20),

                // Section 1: Media Information
                pw.Text(
                  '1. Media Information',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow('Video Name', videoName),
                    _buildTableRow('Scan Date', DateFormat('yyyy-MM-dd HH:mm').format(createdAt)),
                    _buildTableRow('Duration', '${duration.toStringAsFixed(1)} seconds'),
                    _buildTableRow('Processing Time', '${processingTime.toStringAsFixed(1)} seconds'),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Section 2: Forensic Analysis Verdict
                pw.Text(
                  '2. Forensic Analysis Verdict',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: prediction == 'REAL' ? PdfColors.green100 : PdfColors.red100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(
                      color: prediction == 'REAL' ? PdfColors.green800 : PdfColors.red800,
                      width: 1.5,
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Verdict: $prediction',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: prediction == 'REAL' ? PdfColors.green900 : PdfColors.red900,
                            ),
                          ),
                          pw.Text(
                            'Authenticity Score: ${score.toStringAsFixed(1)}%',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: prediction == 'REAL' ? PdfColors.green900 : PdfColors.red900,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'AI Model Confidence Rating: ${confidence.toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey900,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Section 3: Analysis & Reasoning
                pw.Text(
                  '3. Analysis & Reasoning',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    reasoning,
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
                  ),
                ),
                pw.Spacer(),

                // Footer
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated by VeriFrame Deepfake Detection Systems',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Page 1 of 1',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    try {
      final formattedDate = DateFormat('yyyy-MM-dd_HH-mm').format(createdAt);
      final pdfName = 'Verification_Report_$formattedDate.pdf';
      String path = '';

      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download/VeriFrame');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        path = '${downloadsDir.path}/$pdfName';
      } else {
        // Fallback for other platforms (iOS, Desktop)
        final appDocDir = await getApplicationDocumentsDirectory();
        final localDir = Directory('${appDocDir.path}/VeriFrame');
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        path = '${localDir.path}/$pdfName';
      }

      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      debugPrint('[PdfService] Error generating PDF: $e');
      rethrow;
    }
  }

  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }
}
