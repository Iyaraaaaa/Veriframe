import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/verification_repository.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/service/engines/link_verification_engine.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  return VerificationRepositoryImpl();
});

class VerificationNotifier extends StateNotifier<AsyncValue<VerificationResult?>> {
  final VerificationRepository _repository;
  double _uploadProgress = 0.0;
  String _statusMessage = "";

  VerificationNotifier(this._repository) : super(const AsyncValue.data(null));

  double get uploadProgress => _uploadProgress;
  String get statusMessage => _statusMessage;

  void reset() {
    state = const AsyncValue.data(null);
    _uploadProgress = 0.0;
    _statusMessage = "";
  }

  void setStatus(String message, double progress) {
    _statusMessage = message;
    _uploadProgress = progress;
  }

  Future<void> verifyLocalVideo(File file) async {
    state = const AsyncValue.loading();
    _uploadProgress = 0.0;
    _statusMessage = "Uploading video file...";
    try {
      final result = await _repository.verifyLocalVideo(
        file,
        onProgress: (p) {
          _uploadProgress = p;
          _statusMessage = "Uploading... ${(p * 100).toStringAsFixed(0)}%";
        },
      );
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> verifyLink(String url) async {
    state = const AsyncValue.loading();
    _uploadProgress = 0.1;
    _statusMessage = "Initiating video link verification...";
    try {
      final baseUrl = await VerifyBackendService.instance.getBaseUrl();
      final isOnline = await VerifyBackendService.instance.isBackendAvailable(baseUrl);

      if (isOnline) {
        final jobId = await _repository.verifyLink(url);
        
        const int maxPolls = 60;
        int polls = 0;
        while (polls < maxPolls) {
          await Future.delayed(const Duration(seconds: 2));
          polls++;
          
          final statusRes = await VerifyBackendService.instance.getAnalysis(baseUrl, jobId);
          final status = statusRes['status']?.toString().toLowerCase();
          
          if (status == 'downloading') {
            _statusMessage = "Downloading media stream...";
            _uploadProgress = 0.3;
          } else if (status == 'extracting') {
            _statusMessage = "Extracting face crops...";
            _uploadProgress = 0.5;
          } else if (status == 'completed') {
            _statusMessage = "Compiling report...";
            _uploadProgress = 0.9;
            final result = await _repository.createReport(
              jobId: jobId,
              mediaName: url.length > 50 ? '${url.substring(0, 47)}...' : url,
              mediaPath: url,
            );
            state = AsyncValue.data(result);
            return;
          } else if (status == 'failed') {
            throw Exception(statusRes['error'] ?? 'Forensic server failed to verify the link.');
          }
        }
        throw TimeoutException('Verification request timed out on the forensic server.');
      } else {
        _statusMessage = "Running offline link verification...";
        _uploadProgress = 0.2;
        final result = await LinkVerificationEngine.instance.verify(
          url,
          onProgress: (step, progress, message) {
            _statusMessage = message;
            _uploadProgress = progress;
          },
        );
        await _repository.saveResult(result);
        state = AsyncValue.data(result);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> completeStreamSession(String sessionId, String streamUrl) async {
    state = const AsyncValue.loading();
    _statusMessage = "Compiling session report...";
    _uploadProgress = 0.9;
    try {
      final result = await _repository.createReport(
        sessionId: sessionId,
        mediaName: 'Live Camera Stream',
        mediaPath: streamUrl,
      );
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void setResult(VerificationResult result) {
    state = AsyncValue.data(result);
  }
}

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, AsyncValue<VerificationResult?>>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return VerificationNotifier(repo);
});
