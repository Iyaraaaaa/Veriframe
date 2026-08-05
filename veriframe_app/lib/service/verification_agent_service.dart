import 'dart:async';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/service/engines/link_verification_engine.dart';

class VerificationProgress {
  final int stageIndex;
  final String stageName;
  final String statusMessage;
  final double progress;
  final Map<String, dynamic>? metrics;
  final Map<String, dynamic>? finalReport;
  final bool isCompleted;
  final String? error;

  VerificationProgress({
    required this.stageIndex,
    required this.stageName,
    this.statusMessage = '',
    required this.progress,
    this.metrics,
    this.finalReport,
    this.isCompleted = false,
    this.error,
  });
}

class VerificationAgentService {
  VerificationAgentService._();
  static final VerificationAgentService instance = VerificationAgentService._();

  /// Starts Adaptive Link Verification (Stage 1 to 15) with live timeline updates.
  Stream<VerificationProgress> verifyLinkStream(String url) async* {
    final backendService = VerifyBackendService.instance;
    final baseUrl = await backendService.getBaseUrl();

    if (baseUrl.isNotEmpty && await backendService.isBackendAvailable(baseUrl)) {
      String jobId = '';
      try {
        jobId = await backendService.verifyLink(baseUrl, url);
      } catch (e) {
        yield VerificationProgress(
          stageIndex: 0,
          stageName: 'Error',
          progress: 0.0,
          error: 'Failed to initialize verification: $e',
        );
        return;
      }

      // Poll job status every 500ms
      while (true) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          final res = await backendService.getAnalysis(baseUrl, jobId);
          final status = res['status'] ?? '';
          final stage = res['stage'] ?? 'Processing';
          final stageIdx = (res['stage_index'] as num?)?.toInt() ?? 0;
          final progressVal = (res['progress'] as num?)?.toDouble() ?? 0.0;
          final stageData = res['stage_data'] as Map<String, dynamic>?;

          if (status == 'completed') {
            final result = res['result'] as Map<String, dynamic>? ?? {};
            yield VerificationProgress(
              stageIndex: 13,
              stageName: 'Verification Complete',
              statusMessage: 'Forensic report generated successfully.',
              progress: 1.0,
              finalReport: result,
              isCompleted: true,
            );
            break;
          } else if (status == 'failed') {
            yield VerificationProgress(
              stageIndex: stageIdx,
              stageName: stage,
              progress: progressVal,
              error: res['error'] ?? 'Verification failed on server.',
            );
            break;
          } else {
            yield VerificationProgress(
              stageIndex: stageIdx,
              stageName: stage,
              statusMessage: 'Executing stage: $stage',
              progress: progressVal,
              metrics: stageData,
            );
          }
        } catch (e) {
          // Retry on intermittent network glitches
          continue;
        }
      }
    } else {
      // Backend offline fallback - simulate local timeline stages
      yield* _runOfflineSimulatedPipeline(url);
    }
  }

  Stream<VerificationProgress> _runOfflineSimulatedPipeline(String input) async* {
    final stages = [
      'Preparing Analysis',
      'Validating Media',
      'Downloading',
      'Extracting Metadata',
      'Selecting Frames',
      'Detecting Faces',
      'Tracking Faces',
      'Assessing Quality',
      'Running AI Analysis',
      'Verifying Temporal Consistency',
      'Aggregating Evidence',
      'Calibrating Confidence',
      'Generating Report',
      'Verification Complete',
    ];

    final result = await LinkVerificationEngine.instance.verify(input);
    final reportMap = result.toJson();

    for (int i = 0; i < stages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      final isLast = i == stages.length - 1;
      yield VerificationProgress(
        stageIndex: i,
        stageName: stages[i],
        statusMessage: 'Offline Mode: Local rule & cryptographic engine execution',
        progress: (i + 1) / stages.length,
        isCompleted: isLast,
        finalReport: isLast ? reportMap : null,
      );
    }
  }
}
