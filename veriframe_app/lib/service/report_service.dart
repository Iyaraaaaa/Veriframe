import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:veriframe_app/models/report_model.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Stream<List<ReportModel>> getReportsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> saveReport(String uid, ReportModel report) async {
    int retries = 3;
    while (retries > 0) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('reports')
            .doc(report.reportId)
            .set(report.toMap());
        break;
      } catch (e) {
        retries--;
        if (retries == 0) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<File?> downloadReportPdf(String url, String pdfName) async {
    try {
      String savePath = '';
      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download/VeriFrame');
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
        debugPrint('[ReportService] Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ReportService] Download error: $e');
    }
    return null;
  }
}
