import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:veriframe_app/models/verification_result.dart';

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  /// Generates a single-page verification report (mockup style):
  /// header, media/video details, verdict + confidence ring,
  /// analysis index, approval stamp, footer — all on one A4 page.
  Future<File?> generateReportPdf({required VerificationResult result}) async {
    final pdf = pw.Document();

    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDate = formatter.format(result.verifiedAt);
    final bool isAuthentic = result.verdict.toUpperCase() == 'AUTHENTIC';

    // Palette (matches the "paper" analysis-index page style)
    final paperBg = PdfColor.fromHex('#FAF9F6');
    final inkText = PdfColor.fromHex('#1A1A1A');
    final mutedInk = PdfColor.fromHex('#8A8A8A');
    final hairline = PdfColor.fromHex('#DDDAD3');
    final forensicGreen = PdfColor.fromHex('#1F6B45');
    final amberFlag = PdfColor.fromHex('#B8860B');
    final dangerRed = PdfColor.fromHex('#FF3B5C');
    final stampRed = PdfColor.fromHex('#B3231A');

    final statusColor = isAuthentic ? forensicGreen : dangerRed;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            color: paperBg,
            padding: const pw.EdgeInsets.all(36),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- Header ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'VERIFRAME',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.5,
                        color: mutedInk,
                      ),
                    ),
                    pw.Text(
                      result.verificationId,
                      style: pw.TextStyle(fontSize: 9, color: mutedInk),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 0.75, color: hairline),
                pw.SizedBox(height: 14),

                // --- Media / video details (compact) ---
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildDetailLine(
                            'Video',
                            result.mediaName ?? 'Unnamed media',
                            inkText,
                            mutedInk,
                            isBold: true,
                          ),
                          // Source block — always show something, never omit
                          () {
                            final url = result.videoUrl?.trim();
                            final mp = result.mediaPath;
                            final String label;
                            final bool isLink;
                            if (url != null && url.isNotEmpty) {
                              label = url;
                              isLink = true;
                            } else if (mp != null && mp.isNotEmpty && mp.startsWith('stream-')) {
                              label = 'Live camera session — $mp';
                              isLink = false;
                            } else if (mp != null && mp.isNotEmpty) {
                              label = 'Local file: $mp';
                              isLink = false;
                            } else {
                              label = 'Live camera stream (no file)';
                              isLink = false;
                            }
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 6),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Source',
                                    style: pw.TextStyle(
                                      fontSize: 7.5,
                                      color: mutedInk,
                                    ),
                                  ),
                                  pw.SizedBox(height: 1),
                                  if (isLink)
                                    pw.UrlLink(
                                      destination: label,
                                      child: pw.Text(
                                        label,
                                        style: pw.TextStyle(
                                          fontSize: 8.5,
                                          color: PdfColor.fromHex('#1E88E5'),
                                          decoration: pw.TextDecoration.underline,
                                        ),
                                      ),
                                    )
                                  else
                                    pw.Text(
                                      label,
                                      style: pw.TextStyle(
                                        fontSize: 8.5,
                                        color: inkText,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }(),
                          _buildDetailLine(
                            'Verified at',
                            formattedDate,
                            inkText,
                            mutedInk,
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildDetailLine(
                            'Source',
                            result.source,
                            inkText,
                            mutedInk,
                          ),
                          _buildDetailLine(
                            'Media type',
                            result.mediaType,
                            inkText,
                            mutedInk,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),
                pw.Divider(thickness: 0.75, color: hairline),
                pw.SizedBox(height: 18),

                // --- Verdict + confidence ring ---
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Verification result',
                          style: pw.TextStyle(fontSize: 9.5, color: mutedInk),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          isAuthentic ? 'Authentic' : 'Manipulated',
                          style: pw.TextStyle(
                            font: pw.Font.timesBold(),
                            fontSize: 28,
                            color: statusColor,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Risk level \u2014 ${result.riskLevel.toLowerCase()}',
                          style: pw.TextStyle(fontSize: 9.5, color: mutedInk),
                        ),
                      ],
                    ),
                    _buildConfidenceRing(
                      result.confidence,
                      statusColor,
                      inkText,
                      mutedInk,
                    ),
                  ],
                ),
                pw.SizedBox(height: 26),

                // --- Analysis index ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Analysis index',
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: inkText,
                      ),
                    ),
                    pw.Text(
                      'section 04',
                      style: pw.TextStyle(fontSize: 8.5, color: mutedInk),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.75, color: hairline),
                _buildIndexRow(
                  '04.1',
                  'Biometric classifier',
                  'facial structure score',
                  result.manipulationScore,
                  inkText,
                  mutedInk,
                  hairline,
                  forensicGreen,
                  amberFlag,
                  dangerRed,
                ),
                _buildIndexRow(
                  '04.2',
                  'Frame consistency',
                  'histogram correlation',
                  result.frameConsistency,
                  inkText,
                  mutedInk,
                  hairline,
                  forensicGreen,
                  amberFlag,
                  dangerRed,
                ),
                _buildIndexRow(
                  '04.3',
                  'Biometric tracking',
                  'face box displacement',
                  result.trackingConfidence,
                  inkText,
                  mutedInk,
                  hairline,
                  forensicGreen,
                  amberFlag,
                  dangerRed,
                ),
                _buildIndexRow(
                  '04.4',
                  'Metadata verification',
                  'header integrity',
                  result.metadataScore,
                  inkText,
                  mutedInk,
                  hairline,
                  forensicGreen,
                  amberFlag,
                  dangerRed,
                ),
                _buildIndexRow(
                  '04.5',
                  'OCR text confidence',
                  'overlay edge contour',
                  result.ocrConfidence,
                  inkText,
                  mutedInk,
                  hairline,
                  forensicGreen,
                  amberFlag,
                  dangerRed,
                ),

                pw.Spacer(),

                // --- Approval stamp ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Transform.rotate(
                      angle: -0.12,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: stampRed, width: 1.5),
                        ),
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: stampRed, width: 0.75),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                isAuthentic ? 'APPROVED' : 'FLAGGED',
                                style: pw.TextStyle(
                                  font: pw.Font.timesBold(),
                                  fontSize: 13,
                                  color: stampRed,
                                  letterSpacing: 1,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'A. VOSS \u00b7 INSPECTOR',
                                style: pw.TextStyle(
                                  fontSize: 6.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.6,
                                  color: stampRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),

                // --- Footer ---
                pw.Divider(thickness: 0.75, color: hairline),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'VeriFrame biometric media forensics',
                      style: pw.TextStyle(fontSize: 7.5, color: mutedInk),
                    ),
                    pw.Text(
                      '01 / 01',
                      style: pw.TextStyle(fontSize: 7.5, color: mutedInk),
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
      final String fileDate = DateFormat(
        'yyyy-MM-dd_HH-mm',
      ).format(result.verifiedAt);
      final String pdfName =
          'Verification_Report_${result.verificationId}_$fileDate.pdf';
      String path = '';

      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        final downloadsDir = Directory(
          '${extDir?.path ?? "/storage/emulated/0/Download"}/VeriFrame',
        );
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        path = '${downloadsDir.path}/$pdfName';
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        final localDir = Directory('${appDocDir.path}/VeriFrame');
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        path = '${localDir.path}/$pdfName';
      }

      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      debugPrint('[PdfService] Saved report PDF to: $path');
      return file;
    } catch (e) {
      debugPrint('[PdfService] Error saving PDF: $e');
      rethrow;
    }
  }

  pw.Widget _buildDetailLine(
    String label,
    String value,
    PdfColor textColor,
    PdfColor mutedColor, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 7.5, color: mutedColor)),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9.5,
              color: textColor,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildConfidenceRing(
    double value,
    PdfColor ringColor,
    PdfColor textColor,
    PdfColor mutedColor,
  ) {
    return pw.Container(
      width: 78,
      height: 78,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: ringColor, width: 1.5),
      ),
      child: pw.Center(
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              value.toStringAsFixed(1),
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 17,
                color: textColor,
              ),
            ),
            pw.Text(
              'confidence',
              style: pw.TextStyle(fontSize: 6.5, color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildIndexRow(
    String number,
    String label,
    String descriptor,
    double value,
    PdfColor inkText,
    PdfColor mutedInk,
    PdfColor hairline,
    PdfColor greenColor,
    PdfColor amberColor,
    PdfColor redColor,
  ) {
    final valueColor = value >= 85
        ? greenColor
        : (value >= 60 ? amberColor : redColor);

    return pw.Column(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 28,
                child: pw.Text(
                  number,
                  style: pw.TextStyle(fontSize: 7.5, color: mutedInk),
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: inkText,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  descriptor,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, color: mutedInk),
                ),
              ),
              pw.SizedBox(
                width: 60,
                child: pw.Text(
                  '${value.toStringAsFixed(1)}%',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Divider(thickness: 0.5, color: hairline),
      ],
    );
  }

  Future<File?> downloadReportPdf(String url, String pdfName) async {
    try {
      String savePath = '';
      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        final downloadsDir = Directory(
          '${extDir?.path ?? "/storage/emulated/0/Download"}/VeriFrame',
        );
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        savePath = '${downloadsDir.path}/$pdfName';
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        final localDir = Directory('${appDocDir.path}/VeriFrame');
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        savePath = '${localDir.path}/$pdfName';
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        debugPrint(
          '[PdfService] Download failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[PdfService] Download error: $e');
    }
    return null;
  }
}
