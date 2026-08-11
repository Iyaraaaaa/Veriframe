import 'dart:io';
import 'dart:math' as math;
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

                // --- Verified video link ---
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'VERIFIED VIDEO LINK',
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: inkText,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 0.75, color: hairline),
                pw.SizedBox(height: 8),
                _buildVideoLinkSection(
                  result,
                  inkText,
                  hairline,
                ),
                pw.SizedBox(height: 18),

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
                             horizontal: 22,
                             vertical: 10,
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
                                   fontSize: 15,
                                   color: stampRed,
                                   letterSpacing: 2,
                                 ),
                               ),
                               pw.Container(
                                 height: 1,
                                 color: stampRed,
                                 margin: const pw.EdgeInsets.symmetric(vertical: 3),
                               ),
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

  pw.Widget _buildVideoLinkSection(
    VerificationResult result,
    PdfColor inkText,
    PdfColor hairline,
  ) {
    final videoUrl = result.videoUrl?.trim();
    final mp = result.mediaPath;
    final linkBlue = PdfColor.fromHex('#1E88E5');

    if (videoUrl != null && videoUrl.isNotEmpty && Uri.tryParse(videoUrl)?.hasScheme == true) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: videoUrl,
            width: 52,
            height: 52,
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.UrlLink(
                  destination: videoUrl,
                  child: pw.Text(
                    videoUrl,
                    style: pw.TextStyle(
                      color: linkBlue,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Scan or tap to open the evidence video',
                  style: pw.TextStyle(fontSize: 8, color: inkText),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (mp != null && mp.isNotEmpty && mp.startsWith('stream-')) {
      return pw.Text(
        'Live camera session',
        style: pw.TextStyle(fontSize: 9.5, color: inkText),
      );
    } else if (mp != null && mp.isNotEmpty) {
      return pw.Text(
        'Local file only — no shareable link available',
        style: pw.TextStyle(fontSize: 9.5, color: inkText),
      );
    } else {
      return pw.Text(
        'No video evidence available.',
        style: pw.TextStyle(fontSize: 9.5, color: inkText),
      );
    }
  }

  pw.Widget _buildConfidenceRing(
    double value,
    PdfColor ringColor,
    PdfColor textColor,
    PdfColor mutedColor,
  ) {
    final progress = value.clamp(0, 100) / 100;
    const ringSize = 78.0;
    final trackColor = PdfColor.fromHex('#DDDAD3');

    return pw.Container(
      width: ringSize,
      height: ringSize,
      child: pw.CustomPaint(
        size: PdfPoint(ringSize, ringSize),
        painter: (canvas, size) {
          final cx = size.x / 2;
          final cy = size.y / 2;
          final radius = size.x / 2 - 3;
          const startAngle = math.pi / 2;
          const sweepAngle = 2 * math.pi;
          const steps = 60;

          canvas.setStrokeColor(trackColor);
          canvas.setLineWidth(3);
          canvas.drawEllipse(cx, cy, radius, radius);
          canvas.strokePath();

          if (progress > 0.001) {
            final endAngle = startAngle - sweepAngle * progress;
            canvas.setStrokeColor(ringColor);
            canvas.setLineWidth(3);
            canvas.setLineCap(PdfLineCap.round);
            canvas.moveTo(
              cx + radius * math.cos(startAngle),
              cy + radius * math.sin(startAngle),
            );

            for (int i = 1; i <= steps; i++) {
              final t = i / steps;
              final angle = startAngle + (endAngle - startAngle) * t;
              canvas.lineTo(
                cx + radius * math.cos(angle),
                cy + radius * math.sin(angle),
              );
            }
            canvas.strokePath();
          }
        },
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
                'conclusion score',
                style: pw.TextStyle(fontSize: 6.5, color: mutedColor),
              ),
            ],
          ),
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
    final clampedValue = value.clamp(0, 100);

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
                flex: 4,
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
                flex: 4,
                child: pw.LayoutBuilder(
                  builder: (context, constraints) {
                    final fillWidth =
                        (constraints as pw.BoxConstraints).maxWidth * (clampedValue / 100);
                    return pw.Stack(
                      children: [
                        pw.Container(
                          width: double.infinity,
                          height: 6,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#EFEDE6'),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                        pw.Container(
                          width: fillWidth,
                          height: 6,
                          decoration: pw.BoxDecoration(
                            color: valueColor,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    );
                  },
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
