import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/service/engines/video_verification_engine.dart' as video_engine;
import 'package:veriframe_app/service/engines/link_verification_engine.dart';

abstract class VerificationRepository {
  Future<VerificationResult> verifyLocalVideo(
    File file, {
    void Function(double)? onProgress,
  });
  Future<String> verifyLink(String url);
  Future<String> verifyStream(String streamUrl);
  Future<Map<String, dynamic>> analyzeStreamFrame(
    String frameBase64,
    String sessionId,
  );
  Future<VerificationResult> createReport({
    String sessionId = '',
    String jobId = '',
    String? mediaName,
    String? mediaPath,
  });
  Stream<List<VerificationResult>> getHistoryStream();
  Future<void> saveResult(VerificationResult result);
  Future<void> deleteResult(String id);
  Future<void> deleteAllResults();
}

class VerificationRepositoryImpl implements VerificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  Future<String> _getBaseUrl() async {
    return await VerifyBackendService.instance.getBaseUrl();
  }

  @override
  Future<VerificationResult> verifyLocalVideo(
    File file, {
    void Function(double)? onProgress,
  }) async {
    final baseUrl = await _getBaseUrl();
    final isOnline = await VerifyBackendService.instance.isBackendAvailable(
      baseUrl,
    );
    final filename = file.path.split(Platform.pathSeparator).last;

    if (isOnline) {
      // ── Online Forensic Backend Execution ──
      try {
        final res = await VerifyBackendService.instance.predictVideo(
          baseUrl,
          file,
          onUploadProgress: onProgress,
        );

        final result = VerificationResult.fromJson(
          res,
        ).copyWith(mediaName: filename, mediaPath: file.path);

        await _saveToHistory(result);
        return result;
      } catch (e) {
        debugPrint('[Repo] Online analysis error: $e');
        rethrow;
      }
    } else {
      // ── Offline On-device VideoVerificationEngine ──
      debugPrint('[Repo] Server offline. Executing local VideoVerificationEngine.');
      void Function(int step, double progress, String message)? progressCallback;
      if (onProgress != null) {
        progressCallback = (step, progress, message) {
          onProgress(progress);
        };
      }

      final result = await video_engine.VideoVerificationEngine.instance.verifyLocalVideo(
        file,
        onProgress: progressCallback,
      );

      await _saveToHistory(result);
      return result;
    }
  }

  @override
  Future<String> verifyLink(String url) async {
    final baseUrl = await _getBaseUrl();
    final isOnline = await VerifyBackendService.instance.isBackendAvailable(baseUrl);
    if (isOnline) {
      try {
        return await VerifyBackendService.instance.verifyLink(baseUrl, url);
      } catch (e) {
        debugPrint('[Repo] Online link verification failed, falling back to offline link engine: $e');
      }
    }
    final result = await LinkVerificationEngine.instance.verify(url);
    await _saveToHistory(result);
    return result.verificationId;
  }

  @override
  Future<String> verifyStream(String streamUrl) async {
    final baseUrl = await _getBaseUrl();
    return await VerifyBackendService.instance.verifyStream(baseUrl, streamUrl);
  }

  @override
  Future<Map<String, dynamic>> analyzeStreamFrame(
    String frameBase64,
    String sessionId,
  ) async {
    final baseUrl = await _getBaseUrl();
    return await VerifyBackendService.instance.analyzeStreamFrame(
      baseUrl,
      frameBase64,
      sessionId,
    );
  }

  @override
  Future<VerificationResult> createReport({
    String sessionId = '',
    String jobId = '',
    String? mediaName,
    String? mediaPath,
  }) async {
    final baseUrl = await _getBaseUrl();
    final res = await VerifyBackendService.instance.createReport(
      baseUrl,
      sessionId: sessionId,
      jobId: jobId,
    );

    final result = VerificationResult.fromJson(res).copyWith(
      mediaName:
          mediaName ??
          (sessionId.isNotEmpty ? 'Live Stream Session' : 'Video Link Stream'),
      mediaPath: mediaPath ?? '',
    );

    await _saveToHistory(result);
    return result;
  }

  @override
  Stream<List<VerificationResult>> getHistoryStream() {
    if (_uid.isEmpty) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('reports')
        .orderBy('verifiedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => mapToResult(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Future<void> deleteResult(String id) async {
    if (_uid.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('reports')
        .doc(id)
        .delete();
  }

  @override
  Future<void> deleteAllResults() async {
    if (_uid.isEmpty) return;
    const batchLimit = 500;
    while (true) {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('reports')
          .limit(batchLimit)
          .get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < batchLimit) break;
    }
  }

  @override
  Future<void> saveResult(VerificationResult result) => _saveToHistory(result);

  Future<void> _saveToHistory(VerificationResult result) async {
    if (_uid.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('reports')
        .doc(result.verificationId)
        .set(result.toJson());
  }

  VerificationResult mapToResult(Map<String, dynamic> map, String id) {
    if (map.containsKey('videoName') && !map.containsKey('authenticityScore')) {
      final double confidence = (map['confidence'] ?? 0.0).toDouble();
      final double score = (map['score'] ?? 0.0).toDouble();
      final String prediction = map['prediction'] ?? 'REAL';
      final DateTime createdAt = map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now();

      final isReal = prediction.toUpperCase() == 'REAL';
      final authenticityScore = isReal ? score : 100.0 - score;
      final fakeProbability = 100.0 - authenticityScore;

      return VerificationResult(
        verificationId: id,
        verifiedAt: createdAt,
        mediaType: 'video/mp4',
        source: 'Legacy Report',
        authenticityScore: authenticityScore,
        fakeProbability: fakeProbability,
        confidence: confidence,
        metadataScore: 100.0,
        frameConsistency: 100.0,
        ocrConfidence: 0.0,
        trackingConfidence: 100.0,
        manipulationScore: fakeProbability,
        verdict: isReal ? 'AUTHENTIC' : 'MANIPULATED',
        riskLevel: isReal ? 'LOW' : 'HIGH',
        detectedEvidence: [map['reasoning'] ?? 'Legacy verification scan.'],
        forensicObservations: ['Legacy model analysis.'],
        reportHash: map['reportHash'] ?? 'LEGACY-HASH',
        mediaName: map['videoName'] ?? '',
        mediaPath: map['videoPath'] ?? '',
        pdfPath: map['pdfPath'] ?? '',
        thumbnailBase64: map['thumbnail'] ?? '',
      );
    }

    DateTime verifiedAt = DateTime.now();
    if (map['verifiedAt'] != null) {
      if (map['verifiedAt'] is Timestamp) {
        verifiedAt = (map['verifiedAt'] as Timestamp).toDate();
      } else {
        verifiedAt =
            DateTime.tryParse(map['verifiedAt'].toString()) ?? DateTime.now();
      }
    }

    return VerificationResult(
      verificationId: id,
      verifiedAt: verifiedAt,
      mediaType: map['mediaType'] ?? 'video/mp4',
      source: map['source'] ?? 'Local Upload',
      authenticityScore: (map['authenticityScore'] ?? 0.0).toDouble(),
      fakeProbability: (map['fakeProbability'] ?? 0.0).toDouble(),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      metadataScore: (map['metadataScore'] ?? 0.0).toDouble(),
      frameConsistency: (map['frameConsistency'] ?? 0.0).toDouble(),
      ocrConfidence: (map['ocrConfidence'] ?? 0.0).toDouble(),
      trackingConfidence: (map['trackingConfidence'] ?? 0.0).toDouble(),
      manipulationScore: (map['manipulationScore'] ?? 0.0).toDouble(),
      verdict: map['verdict'] ?? 'AUTHENTIC',
      riskLevel: map['riskLevel'] ?? 'LOW',
      detectedEvidence: List<String>.from(map['detectedEvidence'] ?? []),
      forensicObservations: List<String>.from(
        map['forensicObservations'] ?? [],
      ),
      reportHash: map['reportHash'] ?? '',
      mediaName: map['mediaName'] ?? '',
      mediaPath: map['mediaPath'] ?? '',
      pdfPath: map['pdfPath'] ?? '',
      thumbnailBase64: map['thumbnailBase64'] ?? '',
      videoUrl: map['videoUrl'] as String?,
    );
  }
}