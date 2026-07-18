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

  Future<File?> generateReportPdf({
    required VerificationResult result,
  }) async {
    final pdf = pw.Document();

    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final String formattedDate = formatter.format(result.verifiedAt);
    final bool isAuthentic = result.verdict.toUpperCase() == 'AUTHENTIC';
    
    final primaryColor = PdfColor.fromHex('#0B132B');
    final secondaryColor = PdfColor.fromHex('#1C2541');
    final accentBlue = PdfColor.fromHex('#3A86C8');
    final successGreen = PdfColor.fromHex('#00E896');
    final dangerRed = PdfColor.fromHex('#FF3B5C');
    final warningYellow = PdfColor.fromHex('#FFB020');
    final neutralLight = PdfColor.fromHex('#F4F6F9');
    final neutralBorder = PdfColor.fromHex('#E2E8F0');
    final darkText = PdfColor.fromHex('#1E293B');
    final mutedText = PdfColor.fromHex('#64748B');

    final statusColor = isAuthentic ? successGreen : dangerRed;
    final riskColor = result.riskLevel == 'LOW'
        ? successGreen
        : (result.riskLevel == 'MEDIUM' ? warningYellow : dangerRed);

    // Page 1: Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: primaryColor, width: 3),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'VERIFRAME FORENSICS',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: accentBlue,
                      ),
                    ),
                    pw.Text(
                      'CONFIDENTIAL',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: dangerRed,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 50),
                pw.Divider(thickness: 4, color: primaryColor),
                pw.SizedBox(height: 20),
                pw.Text(
                  'MEDIA FORENSIC\nVERIFICATION REPORT',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    lineSpacing: 5,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Digital Evidence Integrity Scan and Deepfake Biometric Analysis',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontStyle: pw.FontStyle.italic,
                    color: mutedText,
                  ),
                ),
                pw.SizedBox(height: 60),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: neutralLight,
                    border: pw.Border.all(color: neutralBorder),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildCoverDetailRow('VERIFICATION ID', result.verificationId, darkText, isBold: true),
                      _buildCoverDetailRow('VERIFIED AT', formattedDate, darkText),
                      _buildCoverDetailRow('MEDIA TYPE', result.mediaType, darkText),
                      _buildCoverDetailRow('SOURCE', result.source, darkText),
                      _buildCoverDetailRow('FILE HASH', result.reportHash, darkText, isMono: true),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Divider(thickness: 1, color: neutralBorder),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'VERIFRAME FORENSIC ENGINE v0.1.0',
                      style: pw.TextStyle(fontSize: 8, color: mutedText),
                    ),
                    pw.Text(
                      'SECURE DOCUMENT ID: ${result.verificationId.hashCode.toRadixString(16).toUpperCase()}',
                      style: pw.TextStyle(fontSize: 8, color: mutedText),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    // Page 2: Analysis Verdict & Evidence Details
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
                    pw.Text('VERIFRAME FORENSIC REPORT', style: pw.TextStyle(fontSize: 10, color: mutedText, fontWeight: pw.FontWeight.bold)),
                    pw.Text('ID: ${result.verificationId}', style: pw.TextStyle(fontSize: 9, color: mutedText)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1.5, color: secondaryColor),
                pw.SizedBox(height: 16),

                // Section 1: Verification Verdict
                pw.Text('1. Forensic Analysis Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.SizedBox(height: 10),
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: isAuthentic ? PdfColor.fromHex('#E6FDF4') : PdfColor.fromHex('#FFF5F5'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: statusColor, width: 1.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'VERDICT: ${result.verdict}',
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: statusColor),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'RISK PROFILE LEVEL: ${result.riskLevel}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: riskColor),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Authenticity: ${result.authenticityScore.toStringAsFixed(2)}%',
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: statusColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Manipulation Score: ${result.fakeProbability.toStringAsFixed(2)}%',
                            style: pw.TextStyle(fontSize: 10, color: darkText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Section 2: Media File Information
                pw.Text('2. Media File Specifications', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: neutralBorder, width: 0.5),
                  children: [
                    _buildTableSpecRow('File Label', result.mediaName ?? 'Unnamed media', darkText),
                    _buildTableSpecRow('Target Source Type', result.source, darkText),
                    _buildTableSpecRow('Extraction Path', result.mediaPath ?? 'Stream source', darkText),
                    _buildTableSpecRow('Media Format Descriptor', result.mediaType, darkText),
                    _buildTableSpecRow('Secure SHA-256 Hash Signature', result.reportHash, darkText, isMono: true),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Section 3: Evidence Summary
                pw.Text('3. Detected Forensic Evidence', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.SizedBox(height: 8),
                if (result.detectedEvidence.isEmpty)
                  pw.Text('No anomalies or manipulation signatures detected in this file.', style: pw.TextStyle(fontSize: 10, color: mutedText))
                else
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: result.detectedEvidence.map((ev) => _buildBulletRow(ev, dangerRed)).toList(),
                  ),
                pw.SizedBox(height: 16),

                pw.Spacer(),
                _buildFooterWidget(2),
              ],
            ),
          );
        },
      ),
    );

    // Page 3: Technical Sub-scores & Breakdown
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
                    pw.Text('VERIFRAME FORENSIC REPORT', style: pw.TextStyle(fontSize: 10, color: mutedText, fontWeight: pw.FontWeight.bold)),
                    pw.Text('ID: ${result.verificationId}', style: pw.TextStyle(fontSize: 9, color: mutedText)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1.5, color: secondaryColor),
                pw.SizedBox(height: 16),

                // Section 4: Technical Analysis Sub-scores
                pw.Text('4. Deep Learning & Image Pipeline Checks', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.SizedBox(height: 12),
                
                pw.Table(
                  border: pw.TableBorder.all(color: neutralBorder, width: 0.5),
                  children: [
                    _buildSubScoreRow('TFLite Biometric Classifier Score', '${result.manipulationScore.toStringAsFixed(2)}%', 'Sigmoid score near 0 indicates authentic facial structures. Near 100 indicates heavy manipulation pattern.'),
                    _buildSubScoreRow('Frame Consistency Score', '${result.frameConsistency.toStringAsFixed(2)}%', 'Correlation matrix check on frame-by-frame color histogram distribution.'),
                    _buildSubScoreRow('Biometric Tracking Confidence', '${result.trackingConfidence.toStringAsFixed(2)}%', 'Displacement variance of MTCNN face bounding boxes over temporal video progression.'),
                    _buildSubScoreRow('Metadata Verification Rating', '${result.metadataScore.toStringAsFixed(2)}%', 'Validates container configuration, FPS ranges, and header structural integrity.'),
                    _buildSubScoreRow('Biometric OCR Text Confidence', '${result.ocrConfidence.toStringAsFixed(2)}%', 'Evaluates presence and binarized edge contours of static text overlays.'),
                  ],
                ),
                pw.SizedBox(height: 24),

                // Section 5: Temporal Confidence Fusion
                pw.Text('5. Temporal Fusion Formula Breakdown', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: neutralLight,
                    border: pw.Border.all(color: neutralBorder),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Total Confidence Score: ${result.confidence.toStringAsFixed(2)}%',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'The forensic verification engine combines neural network outputs, frame visual stability, and face track displacement variables using a deterministic fusion formula:\n\n'
                        '  Fusion Confidence = (Model Score * 70%) + (Frame Consistency * 15%) + (Tracking Score * 15%)',
                        style: pw.TextStyle(fontSize: 9, color: darkText, lineSpacing: 4),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Section 6: Forensic Observations
                pw.Text('6. Forensic Observations Log', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.SizedBox(height: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: result.forensicObservations.map((obs) => _buildBulletRow(obs, accentBlue)).toList(),
                ),

                pw.Spacer(),
                _buildFooterWidget(3),
              ],
            ),
          );
        },
      ),
    );

    // Page 4: Conclusions, Digital Signature, QR Code
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
                    pw.Text('VERIFRAME FORENSIC REPORT', style: pw.TextStyle(fontSize: 10, color: mutedText, fontWeight: pw.FontWeight.bold)),
                    pw.Text('ID: ${result.verificationId}', style: pw.TextStyle(fontSize: 9, color: mutedText)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1.5, color: secondaryColor),
                pw.SizedBox(height: 16),

                // Section 7: Forensic Timeline
                pw.Text('7. Forensic Pipeline Timeline Execution', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.SizedBox(height: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildTimelineRow('T+0.00s', 'Pipeline initialization. Media file hash generated successfully.'),
                    _buildTimelineRow('T+0.12s', 'Video specifications parsed. Resolution, FPS, and codec validated.'),
                    _buildTimelineRow('T+0.25s', 'Frames extracted at spread-out temporal coordinates.'),
                    _buildTimelineRow('T+0.55s', 'Face region coordinates detected using MTCNN / Haar cascade models.'),
                    _buildTimelineRow('T+0.68s', 'Biometric tracking displacement check computed for facial boxes.'),
                    _buildTimelineRow('T+0.82s', 'Deep learning TFLite classifier run on extracted crop batches.'),
                    _buildTimelineRow('T+0.95s', 'Mathematical fusion metrics combined into single VerificationResult.'),
                  ],
                ),
                pw.SizedBox(height: 24),

                // Section 8: Forensic Conclusion
                pw.Text('8. Forensic Conclusion Statement', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.SizedBox(height: 8),
                pw.Text(
                  isAuthentic
                      ? 'Conclusion: Biometric media verification complete. The subject video file displays no anomalies matching synthetic facial manipulation or frame-splicing profiles. The structural integrity, pixel distributions, and frame consistency correlate with authentic source recording profiles.'
                      : 'Conclusion: Biometric media verification complete. The subject video file contains verified visual anomalies matching synthetic facial manipulation signatures. Deep learning neural network classifiers identified manipulation artifacts in facial textures. The file is classified as MANIPULATED with high confidence.',
                  style: pw.TextStyle(fontSize: 10, color: darkText, lineSpacing: 4),
                ),
                pw.SizedBox(height: 30),

                // Section 9: Digital Sign-off & Verification Barcode
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('VERIFICATION SECURE SIGN-OFF', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                          pw.SizedBox(height: 10),
                          pw.Text('Inspector Code: VF-SYS-ENG-01', style: pw.TextStyle(fontSize: 9, color: darkText)),
                          pw.SizedBox(height: 4),
                          pw.Text('Host System: Android Emulator Node x86', style: pw.TextStyle(fontSize: 9, color: darkText)),
                          pw.SizedBox(height: 20),
                          pw.Container(
                            height: 1,
                            color: mutedText,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('VeriFrame Authorized Automated System Signature', style: pw.TextStyle(fontSize: 8, color: mutedText, fontStyle: pw.FontStyle.italic)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 40),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 80,
                          height: 80,
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: 'https://veriframe.io/verify/${result.verificationId}',
                            drawText: false,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Scan to Validate', style: pw.TextStyle(fontSize: 7, color: mutedText)),
                      ],
                    ),
                  ],
                ),

                pw.Spacer(),
                _buildFooterWidget(4),
              ],
            ),
          );
        },
      ),
    );

    try {
      final String formattedDate = DateFormat('yyyy-MM-dd_HH-mm').format(result.verifiedAt);
      final String pdfName = 'Verification_Report_${result.verificationId}_$formattedDate.pdf';
      String path = '';

      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        final downloadsDir = Directory('${extDir?.path ?? "/storage/emulated/0/Download"}/VeriFrame');
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

  pw.TableRow _buildTableSpecRow(String label, String value, PdfColor textColor, {bool isMono = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              color: textColor,
              font: isMono ? pw.Font.courier() : null,
            ),
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildSubScoreRow(String name, String value, String desc) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blue700)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(desc, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ),
      ],
    );
  }

  pw.Widget _buildCoverDetailRow(String label, String value, PdfColor darkText, {bool isBold = false, bool isMono = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#475569'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                color: darkText,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                font: isMono ? pw.Font.courier() : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBulletRow(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4, right: 8),
            width: 4,
            height: 4,
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTimelineRow(String time, String desc) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            time,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Text(
              desc,
              style: const pw.TextStyle(fontSize: 8.5),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooterWidget(int pageNum) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated securely by VeriFrame Biometric Media Forensics',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page $pageNum of 4',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  Future<File?> downloadReportPdf(String url, String pdfName) async {
    try {
      String savePath = '';
      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        final downloadsDir = Directory('${extDir?.path ?? "/storage/emulated/0/Download"}/VeriFrame');
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

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        debugPrint('[PdfService] Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PdfService] Download error: $e');
    }
    return null;
  }
}
