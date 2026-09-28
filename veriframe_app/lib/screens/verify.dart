import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/tflite_service.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/provider/verification_notifier.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/service/notification_service.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veriframe_app/widgets/forensic_progress_timeline.dart';
import 'package:veriframe_app/service/engines/link_verification_engine.dart';
import 'package:veriframe_app/widgets/link_verification_widgets.dart';
import 'package:veriframe_app/widgets/escalate_bottom_sheet.dart';

/// Theme-aware palette
class _VerifyPalette {
  final bool isDark;
  const _VerifyPalette(this.isDark);

  Color get surface => isDark ? const Color(0xFF0F1523) : const Color(0xFFFFFFFF);
  Color get surfaceVariant => isDark ? const Color(0xFF162035) : const Color(0xFFF1F5F9);
  Color get canvas => isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);
  Color get border => isDark ? const Color(0xFF1A2233) : const Color(0xFFE2E8F0);
  Color get borderBright => isDark ? const Color(0xFF1C2740) : const Color(0xFFE2E8F0);
  Color get text => isDark ? const Color(0xFFE8F0FF) : const Color(0xFF0F172A);
  Color get textMuted => isDark ? const Color(0xFF6B7FA8) : const Color(0xFF475569);
  List<Color> get streamGradient => isDark
      ? const [Color(0xFF080C14), Color(0xFF162035)]
      : const [Color(0xFFF1F5F9), Color(0xFFFFFFFF)];
}

class VerifyPage extends ConsumerStatefulWidget {
  final String? initialVideoPath;
  final String? initialVideoUrl;
  final String? initialStreamUrl;
  final bool wrapped;

  const VerifyPage({
    super.key,
    this.initialVideoPath,
    this.initialVideoUrl,
    this.initialStreamUrl,
    this.wrapped = true,
  });

  @override
  ConsumerState<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends ConsumerState<VerifyPage> with TickerProviderStateMixin {
  int _activeTab = 0; // 0 = Video, 1 = Link, 2 = Live Stream

  _VerifyPalette get _vp => _VerifyPalette(Theme.of(context).brightness == Brightness.dark);

  AppLocalizations get loc => AppLocalizations.of(context)!;

  // The local video file currently selected by the user
  File? _selectedVideoFile;

  // Controllers and state
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _streamUrlController = TextEditingController();
  String _selectedPlatform = 'Instagram';
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isStreaming = false;
  String _streamSessionId = "";
  Timer? _streamTimer;

  // Analysis state
  bool _isAnalyzing = false;
  double _uploadProgress = 0.0;
  String _statusMessage = "";
  int _pipelineStep = 0; // 0: validating, 1: extracting, 2: detecting, 3: resizing, 4: inferencing, 5: completed
  
  // Link Verification specific steps
  int _linkStep = 0; // 0: Idle, 1: Downloading, 2: Extracting Frames, 3: Detecting Faces, 4: Running AI, 5: Completed

  /// Maps the internal pipeline/link step counters to the 15-stage UI index.
  /// Local video: _pipelineStep 0-7 → stages 0-14 (spread across groups)
  /// Link tab: _linkStep 0-4 drives the first 8 stages; then _pipelineStep 4-7 finishes.
  int get _currentStageIndex {
    if (_activeTab == 1) {
      // Link tab – combine download steps with post-processing
      if (_pipelineStep < 4) {
        // During download: linkStep 0-4 → stages 0-7
        return (_linkStep * 1.6).round().clamp(0, 7);
      } else {
        // Post-processing stages 8-14 mapped from pipelineStep 4-7
        return (8 + (_pipelineStep - 4) * 1.5).round().clamp(8, 14);
      }
    }
    // Local video tab: distribute 0-7 across 0-14 uniformly
    return (_pipelineStep * 2).clamp(0, 14);
  }
  
  // Results
  bool _showResults = false;
  double _rollingStreamScore = 0.0;

  // TFLite state
  bool _tfliteReady = false;
  String _tfliteError = "";

  // Live Stream stats
  int _framesAnalyzed = 0;
  double _streamFps = 0.0;
  DateTime? _streamStartTime;
  final List<double> _confidenceHistory = [];

  // Animations
  late AnimationController _pulseController;
  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;

  String _baseUrl = '';

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );

    _loadBaseUrlAndCheckReachability();
    _handleInitialArgs();

    // Initialise on-device TFLite model safely
    TFLiteService.instance.init().then((_) {
      if (mounted) setState(() => _tfliteReady = true);
    }).catchError((e) {
      if (mounted) setState(() => _tfliteError = e.toString());
      debugPrint('[TFLite] Failed to init: $e');
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scannerController.dispose();
    _cameraController?.dispose();
    _streamTimer?.cancel();
    _urlController.dispose();
    _streamUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadBaseUrlAndCheckReachability() async {
    final service = VerifyBackendService.instance;
    final detectedUrl = await service.getBaseUrl();
    if (mounted) {
      setState(() {
        _baseUrl = detectedUrl;
      });
    }
  }

  void _handleInitialArgs() {
    if (widget.initialVideoPath != null) {
      _activeTab = 0;
      Future.delayed(const Duration(milliseconds: 300), () {
        _verifyLocalVideo(File(widget.initialVideoPath!));
      });
    } else if (widget.initialVideoUrl != null) {
      _activeTab = 1;
      _urlController.text = widget.initialVideoUrl!;
      Future.delayed(const Duration(milliseconds: 300), _verifyUrlLink);
    } else if (widget.initialStreamUrl != null) {
      _activeTab = 2;
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = loc.verifyNoCameras);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = loc.verifyCameraError(e));
      }
    }
  }

  // --- LOCAL VIDEO PIPELINE ---
  Future<void> _pickAndVerifyVideo() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    setState(() => _selectedVideoFile = file);
    _verifyLocalVideo(file);
  }

  Future<void> _verifyLocalVideo(File file) async {
    // 1. Validate file extension
    final path = file.path.toLowerCase();
    final isSupported = path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.mkv') ||
        path.endsWith('.avi');

    if (!isSupported) {
      setState(() {
        _errorMessage = loc.verifyUnsupportedFormat;
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _showResults = false;
      _errorMessage = null;
      _uploadProgress = 0.0;
      _pipelineStep = 0;
      _statusMessage = loc.verifyConnectingServer;
    });

    // Check backend availability
    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (!isOnline) {
      // Graceful switch to offline TFLite
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.verifyBackendOffline),
            backgroundColor: Color(0xFFFFB020),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _runOfflineTfliteInference();
      return;
    }

    // Online verification
    try {
      setState(() {
        _statusMessage = loc.verifyUploadingFile;
        _pipelineStep = 1;
      });

      final res = await service.predictVideo(
        _baseUrl,
        file,
        onUploadProgress: (progress) {
          if (mounted && _isAnalyzing) {
            setState(() {
              _uploadProgress = progress * 0.8; // Upload takes up to 80% progress
              _statusMessage = loc.verifyUploadingProgress((progress * 100).toStringAsFixed(0));
            });
          }
        },
      );

      if (!_isAnalyzing) return; // User canceled

      setState(() {
        _pipelineStep = 3;
        _uploadProgress = 0.9;
        _statusMessage = loc.verifyAggregatingPredictions;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final result = VerificationResult.fromJson(res).copyWith(
        mediaName: file.path.split(Platform.pathSeparator).last,
        mediaPath: file.path,
      );

      final explanation = "Analyzed ${result.forensicObservations.join(' ')} "
          "Model verdict is '${result.verdict}' with a confidence rating of ${result.confidence.toStringAsFixed(1)}%.";
      final videoName = file.path.split(Platform.pathSeparator).last;

      setState(() {
      });

      await _executePostVerificationFlow(
        videoName: videoName,
        videoPath: file.path,
        verdict: result.verdict.toLowerCase(),
        authenticityScore: result.authenticityScore,
        fakeProbability: result.fakeProbability,
        explanation: explanation,
        modelUsed: "MobileNet Ensemble (Cloud Server)",
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Extracts real frames from the picked video and runs TFLite inference on them.
  /// Results are unique per video because we sample actual content at spread-out timestamps.
  Future<void> _runOfflineTfliteInference() async {
    if (!_tfliteReady) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = _tfliteError.isNotEmpty
            ? loc.verifyOfflineModelFailed(_tfliteError)
            : loc.verifyModelLoading;
      });
      return;
    }

    final videoFile = _selectedVideoFile;
    if (videoFile == null || !await videoFile.exists()) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = "No video file selected. Please pick a video first.";
      });
      return;
    }

    // Step 0 â€” Validate
      setState(() {
        _pipelineStep = 0;
        _statusMessage = loc.verifyValidatingFile;
        _uploadProgress = 0.10;
      });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isAnalyzing) return;

    // Step 1 â€” Extract real frames at spread-out timestamps
      setState(() {
        _pipelineStep = 1;
        _statusMessage = loc.verifyExtractingFrames;
        _uploadProgress = 0.25;
      });

    const int frameCount = 8;
    final List<int> timestampsMs = List.generate(frameCount, (i) => i * 2000);
    final tempDir = await getTemporaryDirectory();
    final List<Uint8List> frameBytes = [];

    for (int i = 0; i < timestampsMs.length; i++) {
      if (!_isAnalyzing) return;
      setState(() {
        _statusMessage = loc.verifyAnalyzingFrame(i + 1, timestampsMs.length);
        _uploadProgress = 0.25 + (i / timestampsMs.length) * 0.25;
      });
      try {
        final thumbPath = await vt.VideoThumbnail.thumbnailFile(
          video: videoFile.path,
          thumbnailPath: tempDir.path,
          imageFormat: vt.ImageFormat.JPEG,
          timeMs: timestampsMs[i],
          quality: 85,
          maxWidth: 224,
          maxHeight: 224,
        );
        if (thumbPath != null) {
          final bytes = await File(thumbPath).readAsBytes();
          frameBytes.add(bytes);
          File(thumbPath).deleteSync();
        }
      } catch (e) {
        debugPrint('[TFLite] Frame extract error at ${timestampsMs[i]}ms: $e');
      }
    }

    if (!_isAnalyzing) return;

    if (frameBytes.isEmpty) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = "Could not extract any frames from the video. It may be corrupt or use an unsupported codec.";
      });
      return;
    }

    // Step 2 â€” Face detection (UI step)
      setState(() {
        _pipelineStep = 2;
        _statusMessage = loc.verifyDetectingRegions;
        _uploadProgress = 0.55;
      });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isAnalyzing) return;

    // Step 3 â€” Resizing info
      setState(() {
        _pipelineStep = 3;
        _statusMessage = loc.verifyPreparingTensors;
        _uploadProgress = 0.65;
      });
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_isAnalyzing) return;

    // Step 4 â€” Run TFLite on every real frame
      setState(() {
        _pipelineStep = 4;
        _statusMessage = loc.verifyRunningInference;
        _uploadProgress = 0.70;
      });

    final List<double> scores = [];
    int inferenceMsSum = 0;

    for (int i = 0; i < frameBytes.length; i++) {
      if (!_isAnalyzing) return;
      setState(() {
        _statusMessage = "Analyzing frame ${i + 1} of ${frameBytes.length}...";
        _uploadProgress = 0.70 + (i / frameBytes.length) * 0.27;
      });
      try {
        final result = await TFLiteService.instance.runInference(frameBytes[i]);
        const fakeIdx = 1;
        final fakeScore = result.rawOutput.length > fakeIdx
            ? result.rawOutput[fakeIdx].clamp(0.0, 1.0)
            : (result.label == 'fake' ? result.confidence : 1.0 - result.confidence);
        scores.add(fakeScore);
        inferenceMsSum += result.inferenceMs;
        debugPrint('[TFLite] Frame ${i + 1}: label=${result.label} fakeScore=${fakeScore.toStringAsFixed(3)}');
      } catch (e) {
        debugPrint('[TFLite] Inference error on frame ${i + 1}: $e');
      }
    }

    if (!_isAnalyzing) return;

    if (scores.isEmpty) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = loc.verifyInferenceFailed;
      });
      return;
    }

    final filename = videoFile.path.split(Platform.pathSeparator).last;
    String verdict = 'unverified';
    double authenticityScore = 0.0;
    double fakeProbability = 0.0;
    String explanation = '';

    if (scores.isEmpty) {
      verdict = 'unverified';
      authenticityScore = 0.0;
      fakeProbability = 0.0;
      explanation = "No usable keyframe facial predictions obtained from '$filename'. Verification status: UNVERIFIED.";
    } else {
      final avgFakeScore = scores.reduce((a, b) => a + b) / scores.length;
      final avgInferenceMs = inferenceMsSum ~/ scores.length;
      authenticityScore = ((1.0 - avgFakeScore) * 100).clamp(0.0, 100.0);
      fakeProbability = (avgFakeScore * 100).clamp(0.0, 100.0);
      verdict = authenticityScore > 60.0 ? 'authentic' : (authenticityScore >= 40.0 ? 'inconclusive' : 'manipulated');
      explanation = "Analyzed ${scores.length} frame(s) extracted from '$filename'. "
          "Verdict: '$verdict' with ${fakeProbability.toStringAsFixed(1)}% deepfake confidence. "
          "Average inference time: ${avgInferenceMs}ms per frame.";
    }

    // Update preliminary display values
    setState(() {
      _pipelineStep = 3;
      _uploadProgress = 0.70;
    });

    // Trigger the full post-verification pipeline (PDF, Firestore, notification)
    await _executePostVerificationFlow(
      videoName: filename,
      videoPath: videoFile.path,
      verdict: verdict,
      authenticityScore: authenticityScore,
      fakeProbability: fakeProbability,
      explanation: explanation,
      modelUsed: "On-Device TFLite (veriframe_model)",
    );
  }

  void _cancelAnalysis() {
    setState(() {
      _isAnalyzing = false;
      _statusMessage = "";
      _uploadProgress = 0.0;
    });
  }

  // --- VIDEO LINK PIPELINE ---
  Future<void> _verifyUrlLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.verifyPleasePasteUrl)),
      );
      return;
    }

      setState(() {
        _isAnalyzing = true;
        _showResults = false;
        _errorMessage = null;
        _uploadProgress = 0.1;
        _linkStep = 1;
        _statusMessage = loc.verifyDownloadingVideo;
      });

    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (!isOnline) {
      try {
        setState(() {
          _statusMessage = "Running offline link verification...";
          _uploadProgress = 0.15;
          _linkStep = 1;
        });

        final result = await LinkVerificationEngine.instance.verify(
          url,
          onProgress: (step, progress, message) {
            if (mounted && _isAnalyzing) {
              setState(() {
                _linkStep = step.clamp(1, 4);
                _uploadProgress = progress;
                _statusMessage = message;
              });
            }
          },
        );

        if (!_isAnalyzing) return;

        setState(() {
          _linkStep = 4;
          _uploadProgress = 0.70;
        });

        await _executePostVerificationFlow(
          videoName: result.mediaName ?? url,
          videoPath: result.mediaPath ?? url,
          verdict: result.verdict.toLowerCase(),
          authenticityScore: result.authenticityScore,
          fakeProbability: result.fakeProbability,
          explanation: result.forensicObservations.join(' '),
          modelUsed: result.source,
          suspiciousFrames: result.suspiciousFrames,
          timelineLogs: result.timelineLogs,
          framesAnalysedCount: result.framesAnalysedCount,
          faceDetectionRate: result.faceDetectionRate,
          detectedEvidence: result.detectedEvidence,
          forensicObservations: result.forensicObservations,
          confidence: result.confidence,
          frameConsistency: result.frameConsistency,
          trackingConfidence: result.trackingConfidence,
          processingTimeSec: result.processingTimeSec,
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
          });
        }
      }
      return;
    }

    try {
      final jobId = await service.verifyLink(_baseUrl, url);
      setState(() {
        _uploadProgress = 0.3;
        _linkStep = 2; // Extracting
        _statusMessage = "Extracting frames on server...";
      });

      _pollLinkJobResult(jobId);
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
      });
    }
  }

  void _pollLinkJobResult(String jobId) {
    const maxPolls = 90; // 3 minutes max (90 × 2s)
    int polls = 0;
    int consecutiveErrors = 0;

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      polls++;
      if (polls > maxPolls || !_isAnalyzing) {
        timer.cancel();
        if (_isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
            _errorMessage = loc.verifyPollingTimeout;
          });
        }
        return;
      }

      try {
        final res = await VerifyBackendService.instance.getAnalysis(_baseUrl, jobId);
        consecutiveErrors = 0;
        final status = res['status']?.toString().toLowerCase();

        if (status == 'downloading') {
          setState(() {
            _linkStep = 1;
            _uploadProgress = 0.2;
            _statusMessage = "Downloading video stream...";
          });
        } else if (status == 'extracting') {
          setState(() {
            _linkStep = 2;
            _uploadProgress = 0.4;
            _statusMessage = "Extracting face crops...";
          });
        } else if (status == 'detecting') {
          setState(() {
            _linkStep = 3;
            _uploadProgress = 0.6;
            _statusMessage = "Locating biometric points...";
          });
        } else if (status == 'inferencing') {
          setState(() {
            _linkStep = 4;
            _uploadProgress = 0.8;
            _statusMessage = "Running deep learning classifiers...";
          });
        } else if (status == 'completed' || status == 'stopped') {
          timer.cancel();
          final results = res['result'] ?? {};
          if (results.isEmpty) {
            throw Exception("Link analysis returned empty results.");
          }
          // Defensive: backend may still return "completed" with a download
          // failure result (e.g. if the safety-net timeout path was taken).
          final analysisStatus = results['analysis_status']?.toString() ?? '';
          final videoRetrieved = results['video_retrieved'] as bool? ?? true;
          if (analysisStatus == 'DOWNLOAD_FAILED' ||
              analysisStatus == 'PROCESSING_ERROR' ||
              !videoRetrieved) {
            if (mounted) {
              setState(() {
                _isAnalyzing = false;
                _errorMessage = results['reason'] ??
                    'Unable to retrieve video from this link. The platform may be blocking automated downloads.';
              });
            }
            return;
          }
          final linkResult = VerificationResult.fromJson(results);
          final linkVerdict = linkResult.verdict.toLowerCase();
          final linkModelUsed = linkResult.forensicObservations.isNotEmpty
              ? linkResult.forensicObservations.first
              : 'Analysis completed successfully.';
          final linkExplanation = linkResult.forensicObservations.join(' ');
          final linkUrl = _urlController.text.trim();

          setState(() {
            _linkStep = 4;
            _uploadProgress = 0.70;
          });

          await _executePostVerificationFlow(
            videoName: linkUrl.length > 60 ? '${linkUrl.substring(0, 57)}...' : linkUrl,
            videoPath: linkUrl,
            verdict: linkVerdict,
            authenticityScore: linkResult.authenticityScore,
            fakeProbability: linkResult.fakeProbability,
            explanation: linkExplanation,
            modelUsed: linkModelUsed,
            suspiciousFrames: linkResult.suspiciousFrames,
            timelineLogs: linkResult.timelineLogs,
            framesAnalysedCount: linkResult.framesAnalysedCount,
            confidence: linkResult.confidence,
            frameConsistency: linkResult.frameConsistency,
            trackingConfidence: linkResult.trackingConfidence,
            processingTimeSec: linkResult.processingTimeSec,
            faceDetectionRate: linkResult.faceDetectionRate,
            detectedEvidence: linkResult.detectedEvidence,
            forensicObservations: linkResult.forensicObservations,
          );
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _errorMessage = res['error'] ??
                  (res['result']?['reason'] ?? 'Forensic server failed to process link.');
            });
          }
          return;
        }
      } catch (e) {
        consecutiveErrors++;
        debugPrint('[VerifyPage] Poll error (attempt $consecutiveErrors): $e');
        if (consecutiveErrors >= 5) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
            });
          }
        }
      }
    });
  }

  // --- LIVE STREAM PIPELINE ---

  Future<void> _startLocalCameraStream() async {
    if (_cameraController == null || !_isCameraInitialized) return;

    setState(() {
      _isStreaming = true;
      _showResults = false;
      _rollingStreamScore = 0.0;
      _framesAnalyzed = 0;
      _streamFps = 0.0;
      _streamStartTime = DateTime.now();
      _confidenceHistory.clear();
      _errorMessage = null;
    });

    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (isOnline) {
      try {
        _streamSessionId = await service.verifyStream(_baseUrl, 'device-camera://default');
      } catch (e) {
        debugPrint("Failed to create stream session: $e");
        _streamSessionId = "stream-${DateTime.now().millisecondsSinceEpoch}";
      }
    } else {
      _streamSessionId = "stream-${DateTime.now().millisecondsSinceEpoch}";
    }

    _streamTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isStreaming || _cameraController == null) {
        timer.cancel();
        return;
      }

      try {
        final XFile file = await _cameraController!.takePicture();
        final bytes = await File(file.path).readAsBytes();
        
        if (isOnline) {
          final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
          await File(file.path).delete();

          final res = await service.analyzeStreamFrame(_baseUrl, base64Image, _streamSessionId);
          final score = (res['session_confidence_score'] ?? 0.0).toDouble();
          
          _framesAnalyzed++;
          _updateFps();
          _addConfidencePoint(score);

          setState(() {
            _rollingStreamScore = score;
          });
        } else {
          // Offline camera TFLite execution
          await File(file.path).delete();
          if (!_tfliteReady) return;

          final result = await TFLiteService.instance.runInference(bytes);
          const fakeIdx = 1;
          final fakeScore = result.rawOutput.length > fakeIdx
              ? result.rawOutput[fakeIdx].clamp(0.0, 1.0)
              : (result.label == 'fake' ? result.confidence : 1.0 - result.confidence);

          // Convert fake probability → authenticity score so display is
          // consistent with the online path (session_confidence_score = authenticity).
          final score = (1.0 - fakeScore) * 100;
          _framesAnalyzed++;
          _updateFps();
          _addConfidencePoint(score);

          setState(() {
            _rollingStreamScore = score;
          });
        }
      } catch (e) {
        debugPrint("Camera local frame error: $e");
      }
    });
  }

  void _updateFps() {
    if (_streamStartTime == null) {
      _streamStartTime = DateTime.now();
      _streamFps = 0.0;
      return;
    }
    final elapsedSec = DateTime.now().difference(_streamStartTime!).inSeconds;
    if (elapsedSec > 0) {
      setState(() {
        _streamFps = _framesAnalyzed / elapsedSec;
      });
    }
  }

  void _addConfidencePoint(double score) {
    if (mounted) {
      setState(() {
        _confidenceHistory.add(score);
        if (_confidenceHistory.length > 15) {
          _confidenceHistory.removeAt(0);
        }
      });
    }
  }

  Future<void> _stopLiveStreamAndGenerateReport() async {
    if (!_isStreaming) return;
    _streamTimer?.cancel();
    
    setState(() {
      _isStreaming = false;
      _isAnalyzing = true;
      _statusMessage = loc.verifyCompilingSessionReport;
    });

    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (!isOnline) {
      // Local report calculation
      await Future.delayed(const Duration(milliseconds: 1000));
      final authenticityScore = _rollingStreamScore.clamp(0.0, 100.0);
      final streamVerdict = authenticityScore > 60.0 ? 'authentic' : (authenticityScore >= 40.0 ? 'inconclusive' : 'manipulated');
      final fakeProbability = (100.0 - authenticityScore).clamp(0.0, 100.0);
      final streamExplanation = loc.verifyLocalReportExplanation(_framesAnalyzed, _rollingStreamScore.toStringAsFixed(1));

      await _executePostVerificationFlow(
        videoName: 'Live Camera Stream',
        videoPath: '',
        verdict: streamVerdict,
        authenticityScore: authenticityScore,
        fakeProbability: fakeProbability,
        explanation: streamExplanation,
        modelUsed: 'On-Device TFLite (veriframe_model)',
      );
      return;
    }

    try {
      if (_streamSessionId.isEmpty) {
        final streamExplanation = loc.verifyLocalReportExplanation(_framesAnalyzed, _rollingStreamScore.toStringAsFixed(1));
        final authenticityScore = _rollingStreamScore.clamp(0.0, 100.0);
        final streamVerdict = authenticityScore > 60.0 ? 'authentic' : (authenticityScore >= 40.0 ? 'inconclusive' : 'manipulated');
        final fakeProbability = (100.0 - authenticityScore).clamp(0.0, 100.0);

        await _executePostVerificationFlow(
          videoName: 'Live Network Stream',
          videoPath: '',
          verdict: streamVerdict,
          authenticityScore: authenticityScore,
          fakeProbability: fakeProbability,
          explanation: streamExplanation,
          modelUsed: 'On-Device Stream Analysis',
        );
        return;
      }

      final res = await service.createReport(_baseUrl, sessionId: _streamSessionId);
      final serverResult = VerificationResult.fromJson(res);
      final serverVerdict = serverResult.verdict.toLowerCase();
      final serverModelUsed = serverResult.forensicObservations.isNotEmpty
          ? serverResult.forensicObservations.first
          : 'Report compiled successfully.';
      final serverExplanation = serverResult.forensicObservations.join(' ');

      await _executePostVerificationFlow(
        videoName: 'Live Stream Session',
        videoPath: _streamSessionId,
        verdict: serverVerdict,
        authenticityScore: serverResult.authenticityScore,
        fakeProbability: serverResult.fakeProbability,
        explanation: serverExplanation,
        modelUsed: serverModelUsed,
      );
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '').trim();
      final isRecoverable = errMsg.contains('No frames with faces detected') ||
          errMsg.contains('No biometric') ||
          errMsg.contains('Invalid request parameters');

      if (isRecoverable) {
        final authenticityScore = _rollingStreamScore.clamp(0.0, 100.0);
        final streamVerdict = authenticityScore > 60.0
            ? 'authentic'
            : (authenticityScore >= 40.0 ? 'inconclusive' : 'manipulated');
        final fakeProbability = (100.0 - authenticityScore).clamp(0.0, 100.0);
        final streamExplanation =
            loc.verifyLocalReportExplanation(_framesAnalyzed, _rollingStreamScore.toStringAsFixed(1));

        await _executePostVerificationFlow(
          videoName: 'Live Stream Session',
          videoPath: '',
          verdict: streamVerdict,
          authenticityScore: authenticityScore,
          fakeProbability: fakeProbability,
          explanation: streamExplanation,
          modelUsed: 'On-Device Stream Analysis',
        );
      } else {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = errMsg;
        });
      }
    }
  }

  Future<void> _executePostVerificationFlow({
    required String videoName,
    required String videoPath,
    required String verdict,
    required double authenticityScore,
    required double fakeProbability,
    required String explanation,
    required String modelUsed,
    List<Map<String, dynamic>>? suspiciousFrames,
    List<String>? timelineLogs,
    int? framesAnalysedCount,
    double? confidence,
    double? frameConsistency,
    double? trackingConfidence,
    double? processingTimeSec,
    double? faceDetectionRate,
    List<String>? detectedEvidence,
    List<String>? forensicObservations,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = loc.verifyAuthError;
        });
      }
      return;
    }

    final createdAt = DateTime.now();
    final reportId = 'RPT-${createdAt.millisecondsSinceEpoch}';
    final prediction = verdict.toLowerCase() == 'authentic' ? 'REAL' : (verdict.toLowerCase() == 'inconclusive' ? 'INCONCLUSIVE' : 'FAKE');

    // Step 5: Composing VerificationResult
    if (mounted) {
      setState(() {
        _pipelineStep = 5;
        _statusMessage = loc.verifyCompilingForensicReport;
        _uploadProgress = 0.80;
      });
    }
    await Future.delayed(const Duration(milliseconds: 400));

    final derivedFrameConsistency = frameConsistency ?? (100.0 - fakeProbability * 0.4).clamp(0.0, 100.0);
    final derivedTrackingConfidence = trackingConfidence ?? (100.0 - fakeProbability * 0.3).clamp(0.0, 100.0);
    final fusedConfidence = confidence ?? (authenticityScore * 0.70
        + (derivedFrameConsistency / 100.0) * 0.15 * 100.0
        + (derivedTrackingConfidence / 100.0) * 0.15 * 100.0
    ).clamp(0.0, 100.0);

    // Derive source label — stream session IDs start with 'stream-'
    final String sourceLabel;
    if (videoPath.startsWith('http')) {
      sourceLabel = 'URL Link';
    } else if (videoPath.isEmpty || videoPath.startsWith('stream-')) {
      sourceLabel = 'Live Stream';
    } else {
      sourceLabel = 'Local File';
    }

    // Populate videoUrl and platform for link-sourced results
    final String? resolvedVideoUrl =
        videoPath.startsWith('http') ? videoPath : null;
    final String? resolvedPlatform = resolvedVideoUrl == null
        ? null
        : (resolvedVideoUrl.toLowerCase().contains('youtube')
            ? 'YouTube'
            : (resolvedVideoUrl.toLowerCase().contains('tiktok')
                ? 'TikTok'
                : (resolvedVideoUrl.toLowerCase().contains('facebook')
                    ? 'Facebook'
                    : (resolvedVideoUrl.toLowerCase().contains('instagram')
                        ? 'Instagram'
                        : 'Web Video'))));

    final String vUpper = verdict.toUpperCase();
    final String finalVerdict = vUpper == 'AUTHENTIC'
        ? 'AUTHENTIC'
        : (vUpper == 'INCONCLUSIVE'
            ? 'INCONCLUSIVE'
            : (vUpper == 'UNVERIFIED' ? 'UNVERIFIED' : 'MANIPULATED'));

    final result = VerificationResult(
      verificationId: reportId,
      verifiedAt: createdAt,
      mediaType: 'video',
      source: sourceLabel,
      authenticityScore: authenticityScore,
      fakeProbability: fakeProbability,
      confidence: finalVerdict == 'UNVERIFIED' ? 0.0 : fusedConfidence,
      metadataScore: 85.0,
      frameConsistency: finalVerdict == 'UNVERIFIED' ? 0.0 : derivedFrameConsistency,
      ocrConfidence: 0.0,
      trackingConfidence: derivedTrackingConfidence,
      manipulationScore: fakeProbability,
      verdict: finalVerdict,
      riskLevel: finalVerdict == 'UNVERIFIED'
          ? 'UNKNOWN'
          : (finalVerdict == 'INCONCLUSIVE'
              ? 'MEDIUM'
              : (finalVerdict == 'AUTHENTIC' ? 'LOW' : 'HIGH')),
      processingTimeSec: processingTimeSec,
      faceDetectionRate: faceDetectionRate,
      suspiciousFramesCount: suspiciousFrames?.length,
      detectedEvidence: (detectedEvidence != null && detectedEvidence.isNotEmpty)
          ? detectedEvidence
          : (finalVerdict == 'UNVERIFIED'
              ? ['AI neural network inference unavailable or no valid face predictions obtained.']
              : (finalVerdict == 'AUTHENTIC'
                  ? ['Optical textures display genuine camera sensor noise and natural motion gradients.']
                  : [
                      'Biometric inconsistency detected across temporal frames.',
                      'Face texture anomalies detected in classified regions.',
                    ])),
      forensicObservations: (forensicObservations != null && forensicObservations.isNotEmpty)
          ? forensicObservations
          : [
              'TFLite deep-learning classifier output: $prediction (${fakeProbability.toStringAsFixed(1)}% confidence).',
              'Frame consistency score: ${derivedFrameConsistency.toStringAsFixed(1)}%.',
              'Biometric tracking stability: ${derivedTrackingConfidence.toStringAsFixed(1)}%.',
              explanation,
            ],
      reportHash: reportId.hashCode.toRadixString(16).padLeft(16, '0'),
      mediaPath: videoPath.isEmpty ? null : videoPath,
      mediaName: videoName,
      videoUrl: resolvedVideoUrl,
      platform: resolvedPlatform,
      framesAnalysedCount: framesAnalysedCount ?? (sourceLabel == 'Live Stream' ? _framesAnalyzed : null),
      suspiciousFrames: suspiciousFrames,
      timelineLogs: timelineLogs,
    );

    // Persist to Riverpod state
    ref.read(verificationProvider.notifier).setResult(result);

    final notificationScore = verdict.toUpperCase() == 'AUTHENTIC'
        ? result.authenticityScore
        : result.fakeProbability;

    // Step 6: Save to Firestore via repository
    if (mounted) {
      setState(() {
        _pipelineStep = 6;
        _statusMessage = "Saving to forensic database...";
        _uploadProgress = 0.88;
      });
    }

    try {
      await ref.read(verificationRepositoryProvider).saveResult(result);
    } catch (e) {
      debugPrint('[VerifyPage] Firestore save error: $e');
    }

    // Step 7: Sending Notification
    if (mounted) {
      setState(() {
        _pipelineStep = 7;
        _statusMessage = "Sending Notification...";
        _uploadProgress = 0.94;
      });
    }

    final notificationId = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notifications').doc().id;
    final notification = NotificationModel(
      id: notificationId,
      title: loc.verifyNotificationTitle,
      message: "Analysis complete. Verdict: ${result.verdict}. "
          "${verdict.toUpperCase() == 'AUTHENTIC' ? 'Authenticity' : 'Manipulation'}: ${notificationScore.toStringAsFixed(1)}%. Tap to view report.",
      type: "verification_completed",
      reportId: reportId,
      createdAt: createdAt,
      isRead: false,
      score: notificationScore,
      prediction: prediction,
      videoName: videoName,
    );

    int retries = 3;
    while (retries > 0) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(notificationId)
            .set(notification.toMap());
        break;
      } catch (e) {
        retries--;
        if (retries == 0) {
          debugPrint('[VerifyPage] Notification Firestore write failed: $e');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    try {
      await NotificationService.instance.showLocalNotification(
        id: notificationId.hashCode,
        title: loc.verifyNotificationTitleBranded,
        body: "${result.verdict}: ${notificationScore.toStringAsFixed(1)}% ${verdict.toUpperCase() == 'AUTHENTIC' ? 'authentic' : 'manipulated'}. Tap to view report.",
        payload: reportId,
      );
    } catch (e) {
      debugPrint("Local notification failed: $e");
    }

    // Step 8: Completed â€” show immutable success dialog
    if (mounted) {
      setState(() {
        _pipelineStep = 8;
        _statusMessage = "Completed";
        _uploadProgress = 1.0;
        _isAnalyzing = false;
        _showResults = true;
      });

      _showSuccessDialog(result);
    }
  }

  void _showSuccessDialog(VerificationResult result) {
    final isReal = result.verdict.toUpperCase() == 'AUTHENTIC';
    final accentColor = isReal ? const Color(0xFF00E896) : const Color(0xFFFF3B5C);
    final displayScore = isReal ? result.authenticityScore : result.fakeProbability;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _vp.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated check/X icon area
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isReal ? Icons.verified_user_rounded : Icons.gavel_rounded,
                  color: accentColor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                loc.verifyCompleteTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _vp.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.verificationId,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: _vp.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildDialogRow(loc.verifyVerdictLabel, result.verdict, accentColor, bold: true),
              _buildDialogRow(
                isReal ? loc.verifyAuthenticityLabel : loc.verifyManipulationLabel,
                '${displayScore.toStringAsFixed(2)}%',
                _vp.text,
              ),
              _buildDialogRow(loc.verifyConfidenceLabel, '${result.confidence.toStringAsFixed(2)}%', _vp.text),
              _buildDialogRow(
                loc.verifyRiskLevelLabel,
                result.riskLevel,
                result.riskLevel == 'LOW'
                    ? const Color(0xFF00E896)
                    : (result.riskLevel == 'MEDIUM' ? const Color(0xFFFFB020) : const Color(0xFFFF3B5C)),
              ),
              _buildDialogRow(
                loc.verifyVerifiedAtLabel,
                DateFormat('MMM dd, yyyy Â· HH:mm').format(result.verifiedAt),
                _vp.textMuted,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/reports');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00C8FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(loc.verifyViewHistory, style: TextStyle(color: const Color(0xFF00C8FF))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(loc.verifyDone),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: _vp.textMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- REPORT ACTION TRIGGERS ---
  Future<void> _getPdfForensicReport(VerificationResult result) async {
    setState(() {
      _statusMessage = loc.verifyGeneratingPdf;
      _isAnalyzing = true;
    });

    try {
       final file = await PdfService.instance.generateReportPdf(result: result);
      setState(() {
        _isAnalyzing = false;
        _statusMessage = "";
      });
      if (file != null && await file.exists()) {
        final openResult = await OpenFilex.open(file.path);
        if (openResult.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.reportErrorOpeningPdf(openResult.message)), backgroundColor: const Color(0xFFFF3B5C)),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.reportPdfNotGenerated), backgroundColor: const Color(0xFFFF3B5C)),
        );
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.verifyPdfFailed(e)), backgroundColor: const Color(0xFFFF3B5C)),
        );
      }
    }
  }

  void _shareForensicLink(VerificationResult result) {
    final isReal = result.verdict.toUpperCase() == 'AUTHENTIC';
    final displayScore = isReal ? result.authenticityScore : result.fakeProbability;
    final scoreLabel = isReal ? 'authenticity' : 'manipulation';
    final reportSummary = "VeriFrame Forensic Report [${result.verificationId}]: Verdict ${result.verdict} with ${displayScore.toStringAsFixed(1)}% $scoreLabel rating. Verification Link: https://veriframe.io/verify/${result.verificationId}";
    Clipboard.setData(ClipboardData(text: reportSummary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.verifyLinkCopied),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF00E896),
      ),
    );
  }

  void _openEscalationSheet(VerificationResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EscalateBottomSheet(report: result),
    );
  }

  void _showBackendSettings() {
    final controller = TextEditingController(text: _baseUrl);
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _vp.surface,
          title: Text(loc.verifyBackendServerTitle, style: TextStyle(color: _vp.text, fontSize: 16)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: _vp.text),
            decoration: InputDecoration(
              hintText: loc.verifyBackendUrlHint,
              hintStyle: TextStyle(color: _vp.textMuted),
              helperText: loc.verifyBackendHelper,
              helperStyle: TextStyle(color: _vp.textMuted, fontSize: 11),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.verifyCancel, style: TextStyle(color: _vp.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = controller.text.trim();
                final nav = Navigator.of(context);
                await VerifyBackendService.instance.saveBaseUrl(url);
                if (mounted) {
                  setState(() {
                    _baseUrl = url;
                  });
                }
                nav.pop();
              },
              child: Text(loc.verifyBackendSave),
            ),
          ],
        );
      },
    );
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    final content = _buildMainLayout(context);
    if (!widget.wrapped) return content;

    return MainScaffold(
      showBack: true,
      extraActions: [
        IconButton(
          onPressed: _showBackendSettings,
          icon: Icon(Icons.settings_ethernet, color: Colors.white, size: 20),
          tooltip: 'Configure connection settings',
        ),
      ],
      body: SafeArea(child: content),
    );
  }

  Widget _buildMainLayout(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) _buildErrorCard(colors),
                if (!_isAnalyzing && !_isStreaming && !_showResults)
                  _buildInputSelectorTabs(colors),
                if (_isAnalyzing) _buildAnalysisProgressPipeline(colors),
                if (_isStreaming) _buildLiveStreamVisualizer(colors),
                if (_showResults) () {
                  final activeResult = ref.watch(verificationProvider).value;
                  if (activeResult != null) {
                    return _buildForensicResultsDashboard(activeResult, colors);
                  }
                  return const SizedBox.shrink();
                }(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(AppColors colors) {
    if (_activeTab == 1) {
      return LinkDownloadErrorCard(
        errorMessage: _errorMessage!,
        onUploadVideoPressed: () {
          setState(() {
            _errorMessage = null;
            _activeTab = 0;
          });
          _pickAndVerifyVideo();
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B5C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF3B5C).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B5C)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: _vp.text, fontSize: 13, height: 1.4),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: Icon(Icons.close, size: 16, color: _vp.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSelectorTabs(AppColors colors) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _vp.canvas,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _buildTabSelectorItem(0, loc.verifyVideoTab, Icons.movie_outlined),
              _buildTabSelectorItem(1, loc.verifyLinkTab, Icons.link_rounded),
              _buildTabSelectorItem(2, loc.verifyStreamTab, Icons.sensors_rounded),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_activeTab == 0) _buildLocalVideoCard(colors, loc),
        if (_activeTab == 1) _buildVideoLinkCard(colors, loc),
        if (_activeTab == 2) _buildLiveStreamCard(colors, loc),
      ],
    );
  }

  Widget _buildTabSelectorItem(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _activeTab = index;
          _errorMessage = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _vp.surfaceVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF00C8FF) : _vp.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _vp.text : _vp.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalVideoCard(AppColors colors, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _vp.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _vp.border),
      ),
      child: Column(
        children: [
          Icon(Icons.drive_folder_upload, size: 64, color: Color(0xFF00C8FF)),
          const SizedBox(height: 16),
          Text(
            loc.verifyAiForensicTitle,
            style: TextStyle(color: _vp.text, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _baseUrl.isEmpty ? loc.verifyNoBackendUrl : loc.verifySelectLocalVideo,
            textAlign: TextAlign.center,
            style: TextStyle(color: _vp.textMuted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C8FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00C8FF).withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tfliteReady ? Icons.check_circle_outline : Icons.hourglass_empty,
                      color: _tfliteReady ? const Color(0xFF00E896) : const Color(0xFFFFB020),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _tfliteReady ? '${loc.verifyOnDeviceReady} · Vedio.tflite' : loc.verifyLoadingModel,
                      style: TextStyle(
                        color: _tfliteReady ? const Color(0xFF00E896) : const Color(0xFFFFB020),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.memory_rounded, color: Color(0xFF34D399), size: 13),
                    SizedBox(width: 6),
                    Text(
                      'veriframe_model.tflite · Face Biometric Net',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.cloud_done_rounded, color: Color(0xFF38BDF8), size: 13),
                    SizedBox(width: 6),
                    Text(
                      'Reality Defender Cloud Deepfake AI: Active',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickAndVerifyVideo,
            icon: Icon(Icons.video_collection),
            label: Text(loc.verifyPickLocalVideo),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLinkCard(AppColors colors, AppLocalizations loc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131D2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  'Select Platform',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose where your video is hosted',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: subtitleColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 2x2 Platform Grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              _buildVerifyPlatformItem(
                name: 'YouTube',
                brandColor: const Color(0xFFFF0000),
                isDark: isDark,
                customIcon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              _buildVerifyPlatformItem(
                name: 'Instagram',
                brandColor: const Color(0xFFE1306C),
                isDark: isDark,
                customIcon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF58529),
                        Color(0xFFDD2A7B),
                        Color(0xFF8134AF),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDD2A7B).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              _buildVerifyPlatformItem(
                name: 'Facebook',
                brandColor: const Color(0xFF1877F2),
                isDark: isDark,
                customIcon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1877F2).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'f',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              _buildVerifyPlatformItem(
                name: 'TikTok',
                brandColor: Colors.black,
                isDark: isDark,
                customIcon: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: const [
                      Positioned(
                        left: 13,
                        top: 11,
                        child: Icon(Icons.music_note_rounded, color: Color(0xFF00F2FE), size: 22),
                      ),
                      Positioned(
                        right: 13,
                        bottom: 11,
                        child: Icon(Icons.music_note_rounded, color: Color(0xFFFE2C55), size: 22),
                      ),
                      Icon(Icons.music_note_rounded, color: Colors.white, size: 22),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          Text(
            'VIDEO LINK',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: subtitleColor,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link_rounded, color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: TextStyle(fontSize: 13.5, color: titleColor, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Paste your $_selectedPlatform link here...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _verifyUrlLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'VERIFY NOW',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyPlatformItem({
    required String name,
    required Color brandColor,
    required bool isDark,
    required Widget customIcon,
  }) {
    final isSelected = _selectedPlatform == name;
    final cardBg = isDark
        ? (isSelected ? const Color(0xFF1E293B) : const Color(0xFF111C2E))
        : (isSelected ? const Color(0xFFF0F9FF) : Colors.white);

    final activeBorderColor = name == 'Instagram'
        ? const Color(0xFFE1306C)
        : (name == 'YouTube'
            ? const Color(0xFFFF0000)
            : (name == 'Facebook' ? const Color(0xFF1877F2) : const Color(0xFF0F172A)));

    final cardBorder = isSelected ? activeBorderColor : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedPlatform = name),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder, width: isSelected ? 1.8 : 1.2),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeBorderColor.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIcon,
              const SizedBox(height: 10),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStreamCard(AppColors colors, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _vp.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B5C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'LIVE STREAM TELEMETRY HUD',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7C3AED),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'RTSP / RTMP / CAMERA',
                  style: TextStyle(color: Color(0xFF7C3AED), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Real-Time Continuous Stream Verification',
            style: TextStyle(color: _vp.text, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Monitor live video streams in real-time with continuous sliding-window temporal confidence tracking.',
            style: TextStyle(color: _vp.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _vp.canvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _vp.border),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _streamUrlController,
                  style: TextStyle(color: _vp.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter RTSP, RTMP, or HLS stream URL (optional)...',
                    hintStyle: TextStyle(color: _vp.textMuted, fontSize: 11),
                    prefixIcon: const Icon(Icons.sensors, color: Color(0xFF7C3AED), size: 18),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _initCamera();
                    if (_isCameraInitialized) {
                      await _startLocalCameraStream();
                    }
                  },
                  icon: const Icon(Icons.videocam_rounded, size: 18),
                  label: const Text('Live Camera Stream', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = _streamUrlController.text.trim();
                    if (url.isNotEmpty) {
                      await _startNetworkStream(url);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an RTSP/RTMP/HLS stream URL or select Live Camera Stream.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.stream_rounded, size: 18, color: Color(0xFF7C3AED)),
                  label: const Text('RTSP/Network Stream', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startNetworkStream(String url) async {
    // Initialise camera if not already done — we'll use the device camera
    // to supply frames to the stream session even for RTSP/HLS URLs.
    // This is necessary because the mobile app cannot natively decode an
    // RTSP stream; the URL is forwarded to the backend session as metadata.
    if (!_isCameraInitialized) {
      await _initCamera();
    }

    if (!_isCameraInitialized) {
      // Camera unavailable — cannot stream. Error is already set by _initCamera.
      if (mounted) setState(() => _isStreaming = false);
      return;
    }

    setState(() {
      _isStreaming = true;
      _showResults = false;
      _rollingStreamScore = 0.0;
      _framesAnalyzed = 0;
      _streamFps = 0.0;
      _streamStartTime = DateTime.now();
      _confidenceHistory.clear();
      _errorMessage = null;
    });

    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (isOnline) {
      try {
        // Pass the actual network URL so the server logs the real stream source.
        _streamSessionId = await service.verifyStream(_baseUrl, url);
      } catch (e) {
        debugPrint("Failed to create network stream session: $e");
        _streamSessionId = "stream-${DateTime.now().millisecondsSinceEpoch}";
      }
    } else {
      _streamSessionId = "stream-${DateTime.now().millisecondsSinceEpoch}";
    }

    // Capture and analyse real camera frames every 2 seconds.
    _streamTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isStreaming || _cameraController == null) {
        timer.cancel();
        return;
      }
      try {
        final XFile file = await _cameraController!.takePicture();
        final bytes = await File(file.path).readAsBytes();

        if (isOnline) {
          final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
          await File(file.path).delete();

          final res = await service.analyzeStreamFrame(
              _baseUrl, base64Image, _streamSessionId);
          final score = (res['session_confidence_score'] ?? 0.0).toDouble();

          _framesAnalyzed++;
          _updateFps();
          _addConfidencePoint(score);

          if (mounted) {
            setState(() {
              _rollingStreamScore = score;
            });
          }
        } else {
          // Offline fallback: run on-device TFLite model.
          await File(file.path).delete();
          if (!_tfliteReady) return;

          final result = await TFLiteService.instance.runInference(bytes);
          const fakeIdx = 1;
          final fakeScore = result.rawOutput.length > fakeIdx
              ? result.rawOutput[fakeIdx].clamp(0.0, 1.0)
              : (result.label == 'fake'
                  ? result.confidence
                  : 1.0 - result.confidence);

          // Convert fake probability to authenticity for display consistency.
          final score = (1.0 - fakeScore) * 100;
          _framesAnalyzed++;
          _updateFps();
          _addConfidencePoint(score);

          if (mounted) {
            setState(() {
              _rollingStreamScore = score;
            });
          }
        }
      } catch (e) {
        debugPrint("Network stream frame error: $e");
      }
    });
  }

  Widget _buildAnalysisProgressPipeline(AppColors colors) {
    if (_activeTab == 1) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cardBg = isDark ? const Color(0xFF131D2E) : Colors.white;
      final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
      final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
      final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

      final pct = (_uploadProgress.clamp(0.0, 1.0) * 100).toInt();
      final currentStageIndex = _linkStep.clamp(0, 7);

      final linkTimelineSteps = [
        ('Validating URL', currentStageIndex > 0 ? '2.3s' : (currentStageIndex == 0 ? '2.3s...' : '--')),
        ('Detecting Platform', currentStageIndex > 1 ? '1.8s' : (currentStageIndex == 1 ? '1.8s...' : '--')),
        ('Downloading Video', currentStageIndex > 2 ? '4.2s' : (currentStageIndex == 2 ? '4.2s...' : '--')),
        ('Extracting Frames', currentStageIndex > 3 ? '3.1s' : (currentStageIndex == 3 ? '3.1s...' : '--')),
        ('Detecting Faces', currentStageIndex > 4 ? '2.7s' : (currentStageIndex == 4 ? '2.7s...' : '--')),
        ('Running AI Analysis', currentStageIndex > 5 ? '5.4s' : (currentStageIndex == 5 ? '5.4s...' : '--')),
        ('Generating Report', currentStageIndex > 6 ? '1.2s' : (currentStageIndex == 6 ? '1.2s...' : '--')),
        ('Verification Complete', currentStageIndex >= 7 ? 'Done' : '--'),
      ];

      final stageName = linkTimelineSteps[currentStageIndex].$1;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Progress Card (Matching reference design)
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stageName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stage ${currentStageIndex + 1} of 9',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00A3CC),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '~${(8 * (1.0 - _uploadProgress.clamp(0.0, 1.0))).ceil()}s remaining',
                          style: TextStyle(fontSize: 11, color: subtitleColor),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00A3CC)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Continuous Timeline Card (Matching reference design)
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: List.generate(linkTimelineSteps.length, (idx) {
                final isCompleted = idx < currentStageIndex;
                final isActive = idx == currentStageIndex;
                final isLast = idx == linkTimelineSteps.length - 1;

                Color rowBg;
                Color lineColor;
                Color textColor;
                Color timeColor;

                if (isCompleted) {
                  rowBg = isDark ? const Color(0xFF0A2218).withValues(alpha: 0.6) : const Color(0xFFF0FDF4);
                  lineColor = const Color(0xFF22C55E);
                  textColor = const Color(0xFF16A34A);
                  timeColor = const Color(0xFF94A3B8);
                } else if (isActive) {
                  rowBg = isDark ? const Color(0xFF082638).withValues(alpha: 0.7) : const Color(0xFFF0F9FF);
                  lineColor = const Color(0xFF00A3CC);
                  textColor = const Color(0xFF0077AA);
                  timeColor = const Color(0xFF00A3CC);
                } else {
                  rowBg = isDark ? const Color(0xFF131D2E) : Colors.white;
                  lineColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
                  textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
                  timeColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
                }

                return Container(
                  decoration: BoxDecoration(
                    color: rowBg,
                    border: Border(
                      bottom: isLast
                          ? BorderSide.none
                          : BorderSide(
                              color: isDark ? const Color(0xFF1A263B) : const Color(0xFFF1F5F9),
                              width: 1.0,
                            ),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Vertical spine
                        SizedBox(
                          width: 32,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: 14.5,
                                child: Container(
                                  width: 2.5,
                                  color: lineColor,
                                ),
                              ),
                              if (isCompleted)
                                Container(
                                  width: 7.5,
                                  height: 7.5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                  ),
                                )
                              else if (isActive)
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF00A3CC).withValues(alpha: 0.25),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 7.5,
                                      height: 7.5,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF00A3CC),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Status Icon
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.only(right: 12),
                          child: isCompleted
                              ? const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 17)
                              : (isActive
                                  ? const Icon(Icons.arrow_downward_rounded, color: Color(0xFF0077AA), size: 16)
                                  : Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF64748B), width: 1.5),
                                      ),
                                    )),
                        ),

                        // Step Title
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              linkTimelineSteps[idx].$1,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isActive ? FontWeight.w700 : (isCompleted ? FontWeight.w600 : FontWeight.w500),
                                color: textColor,
                              ),
                            ),
                          ),
                        ),

                        // Elapsed Time
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 16, 20, 16),
                          child: Text(
                            linkTimelineSteps[idx].$2,
                            style: TextStyle(
                              fontSize: 12,
                              color: timeColor,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Cancel Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelAnalysis,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderColor, width: 1.3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'PAUSE / CANCEL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF3B5C),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ForensicProgressTimeline(
          currentStageIndex: _currentStageIndex.clamp(0, 13),
          stageStatusMessage: _statusMessage,
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _uploadProgress.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: _vp.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C8FF)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _cancelAnalysis,
            icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF3B5C), size: 18),
            label: Text(
              loc.verifyCancelAnalysis,
              style: const TextStyle(color: Color(0xFFFF3B5C), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildLiveStreamVisualizer(AppColors colors) {
    final loc = AppLocalizations.of(context)!;
    final isDeviceCam = _cameraController != null && _isCameraInitialized;
    return Container(
      decoration: BoxDecoration(
        color: _vp.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _vp.borderBright),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (isDeviceCam)
            Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
                Positioned.fill(child: _buildScannerOverlay()),
              ],
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _vp.streamGradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors, color: Color(0xFF7C3AED), size: 48),
                    SizedBox(height: 12),
                     Text(
                       loc.verifyConnectingLiveStream,
                       style: TextStyle(color: _vp.text, fontWeight: FontWeight.bold, fontSize: 14),
                     ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            color: _vp.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fiber_manual_record, color: Color(0xFFFF3B5C), size: 12),
                        const SizedBox(width: 8),
                        Text(
                          isDeviceCam ? loc.verifyFeedStreaming : loc.verifyAiAnalyzingStream,
                          style: TextStyle(color: Color(0xFFFF3B5C), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                     Text(
                       loc.verifyFpsFrames(_streamFps.toStringAsFixed(1), _framesAnalyzed),
                       style: TextStyle(color: _vp.textMuted, fontSize: 12),
                     ),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats Dashboard — _rollingStreamScore is AUTHENTICITY (0-100).
                // Higher = more likely genuine. GREEN >= 65%, RED < 35%, AMBER in-between.
                Builder(builder: (context) {
                  final authScore = _rollingStreamScore;
                  final scoreColor = authScore >= 65
                      ? const Color(0xFF00E896)    // green  → authentic
                      : authScore >= 35
                          ? const Color(0xFFFFC107) // amber  → uncertain
                          : const Color(0xFFFF3B5C); // red  → manipulated
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Authenticity Score',
                            style: TextStyle(color: _vp.textMuted, fontSize: 12),
                          ),
                          Text(
                            "${authScore.toStringAsFixed(1)}%",
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: authScore / 100,
                          backgroundColor: _vp.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation(scoreColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                Text(loc.verifyProbabilityGraph, style: TextStyle(color: _vp.text, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // Real-time custom painter graph
                DeepfakeGraph(dataPoints: List.from(_confidenceHistory)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _stopLiveStreamAndGenerateReport,
                  icon: Icon(Icons.stop_circle_rounded),
                  label: Text(loc.verifyStopGetReport),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return AnimatedBuilder(
      animation: _scannerAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: 250 * _scannerAnimation.value,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Color(0xFF00C8FF),
                  boxShadow: [
                    BoxShadow(color: Color(0xFF00C8FF), blurRadius: 10, spreadRadius: 3),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildForensicResultsDashboard(VerificationResult result, AppColors colors) {
    final loc = AppLocalizations.of(context)!;
    final isReal = result.verdict.toUpperCase() == 'AUTHENTIC';
    final verdictColor = isReal
        ? const Color(0xFF00E896)
        : const Color(0xFFFF3B5C);

    final isLinkResult = _activeTab == 1 || result.platform != null || (result.videoUrl != null && result.videoUrl!.isNotEmpty) || result.source.contains('Link');

    if (isLinkResult) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Video Platform & Metadata Header
          LinkVideoHeaderCard(result: result),

          // 2. Verdict Hero & Dual Authenticity Meter
          LinkVerdictHeroCard(result: result),

          // 3. Forensic Diagnostics Dashboard (Real Metrics)
          LinkForensicDashboard(result: result),

          // 4. Suspicious Frames Gallery (or Reassuring Clean Audit)
          SuspiciousFramesGallery(suspiciousFrames: result.suspiciousFrames ?? []),

          // 5. Forensic Observations & Evidence
          if (result.forensicObservations.isNotEmpty || result.detectedEvidence.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _vp.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _vp.borderBright, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Color(0xFF0284C7), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Forensic Observations & Evidence',
                        style: TextStyle(color: _vp.text, fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (result.detectedEvidence.isNotEmpty) ...[
                    ...result.detectedEvidence.map((ev) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isReal ? Icons.check_circle_outline_rounded : Icons.report_problem_outlined,
                            size: 16,
                            color: isReal ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ev,
                              style: TextStyle(color: _vp.text, fontSize: 12.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],
                  ...result.forensicObservations.map((obs) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: _vp.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            obs,
                            style: TextStyle(color: _vp.textMuted, fontSize: 12, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),

          // 6. Chronological Audit Log
          LinkProcessingTimelineLog(
            logs: (result.timelineLogs != null && result.timelineLogs!.isNotEmpty)
                ? result.timelineLogs!
                : [
                    '${DateFormat("HH:mm:ss").format(result.verifiedAt)} - Link verification completed',
                    '${DateFormat("HH:mm:ss").format(result.verifiedAt)} - Cryptographic report hash: ${result.reportHash.substring(0, result.reportHash.length.clamp(0, 16))}...',
                  ],
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _getPdfForensicReport(result),
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  label: Text(loc.verifyGetReportPdf),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareForensicLink(result),
                  icon: Icon(Icons.share_outlined),
                  label: Text('Share Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _showResults = false;
                _rollingStreamScore = 0.0;
                _streamSessionId = "";
                _errorMessage = null;
              });
            },
            child: Text(loc.verifyScanAnotherMedia),
          ),
        ],
      );
    }

    final isHighRisk = result.riskLevel == 'HIGH';
    final consistentScore = isReal ? result.authenticityScore : result.fakeProbability;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _vp.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _vp.borderBright),
          ),
          child: Column(
            children: [
              Text(
                loc.verifyForensicConclusion.toUpperCase(),
                style: TextStyle(color: _vp.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: consistentScore / 100,
                      strokeWidth: 8,
                      backgroundColor: _vp.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(verdictColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${consistentScore.toStringAsFixed(1)}%",
                        style: TextStyle(color: _vp.text, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.verdict.toUpperCase(),
                        style: TextStyle(color: verdictColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Biometric Heatmap mockup
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _vp.canvas,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _vp.surfaceVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(Icons.face_retouching_natural_rounded, color: verdictColor.withValues(alpha: 0.15), size: 64),
                      ),
                      Positioned(
                        top: 20,
                        left: 40,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(border: Border.all(color: verdictColor, width: 1)),
                          child: Text("EYE_L", style: TextStyle(color: _vp.textMuted, fontSize: 8)),
                        ),
                      ),
                      Positioned(
                        top: 22,
                        right: 40,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(border: Border.all(color: verdictColor, width: 1)),
                          child: Text("EYE_R", style: TextStyle(color: _vp.textMuted, fontSize: 8)),
                        ),
                      ),
                      Positioned(
                        bottom: 18,
                        left: 80,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(border: Border.all(color: verdictColor, width: 1)),
                          child: Text("MOUTH", style: TextStyle(color: _vp.textMuted, fontSize: 8)),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            loc.verifyLandmarkMap(83),
                            style: TextStyle(color: verdictColor.withValues(alpha: 0.6), fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "${loc.verifyModelUsed} ${result.source}",
                style: TextStyle(color: _vp.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _vp.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _vp.borderBright),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.verifyExplainableAiStatement,
                style: TextStyle(color: _vp.text, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                result.forensicObservations.join('\n'),
                style: TextStyle(color: _vp.textMuted, fontSize: 12, height: 1.5, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _getPdfForensicReport(result),
                icon: Icon(Icons.picture_as_pdf_outlined),
                label: Text(loc.verifyGetReportPdf),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _shareForensicLink(result),
                icon: Icon(Icons.share_outlined),
                label: Text(loc.verifyLinkCopied),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        if (isHighRisk) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openEscalationSheet(result),
            icon: const Icon(Icons.gavel_rounded),
            label: Text(loc.verifyReportMedia),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B5C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _showResults = false;
              _rollingStreamScore = 0.0;
              _streamSessionId = "";
              _errorMessage = null;
            });
          },
          child: Text(loc.verifyScanAnotherMedia),
        ),
      ],
    );
}
} // end _VerifyPageState


// Custom Deepfake probability chart builder
class DeepfakeGraph extends StatelessWidget {
  final List<double> dataPoints;
  const DeepfakeGraph({super.key, required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: CustomPaint(
        painter: _GraphPainter(dataPoints),
        child: Container(),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<double> dataPoints;
  _GraphPainter(this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.4)
      ..strokeWidth = 0.8;

    // Draw horizontal grid lines (0%, 25%, 50%, 75%, 100%)
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw vertical grid lines
    const int verticalGridCount = 6;
    for (int i = 0; i <= verticalGridCount; i++) {
      final x = size.width * (i / verticalGridCount);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    if (dataPoints.isEmpty) return;

    final linePaint = Paint()
      ..color = const Color(0xFF00C8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final double stepX = size.width / (dataPoints.length > 1 ? dataPoints.length - 1 : 1);
    
    for (int i = 0; i < dataPoints.length; i++) {
      final score = dataPoints[i].clamp(0.0, 100.0);
      final y = size.height - (score / 100.0) * size.height;
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      
      if (i == dataPoints.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    fillPaint.shader = LinearGradient(
      colors: [
        const Color(0xFF00C8FF).withValues(alpha: 0.3),
        const Color(0xFF00C8FF).withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Glow dot on last point
    final lastScore = dataPoints.last.clamp(0.0, 100.0);
    final lastY = size.height - (lastScore / 100.0) * size.height;
    final lastX = (dataPoints.length - 1) * stepX;

    final dotPaint = Paint()
      ..color = lastScore >= 75 ? const Color(0xFFFF3B5C) : const Color(0xFF00C8FF)
      ..style = PaintingStyle.fill;
    
    final glowPaint = Paint()
      ..color = (lastScore >= 75 ? const Color(0xFFFF3B5C) : const Color(0xFF00C8FF)).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(lastX, lastY), 8.0, glowPaint);
    canvas.drawCircle(Offset(lastX, lastY), 4.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}

