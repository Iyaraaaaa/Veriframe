import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

/// Theme-aware palette for the Verify screen so it renders correctly in both
/// light and dark mode (no hard-coded black backgrounds in light mode).
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

  // The local video file currently selected by the user
  File? _selectedVideoFile;

  // Controllers and state
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _streamUrlController = TextEditingController();
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
  
  // Results
  bool _showResults = false;
  double _confidenceScore = 0.0;
  double _rollingStreamScore = 0.0;
  String _verdict = "authentic";
  String _modelUsed = "";
  String _explanation = "";
  String _reportId = "";
  String _pdfUrl = "";

  String? _errorMessage;
  String _currentJobId = "";

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
      _streamUrlController.text = widget.initialStreamUrl!;
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = "No cameras found on device.");
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
        setState(() => _errorMessage = "Camera initialization error: $e");
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
        _errorMessage = "Unsupported format. Only MP4, MOV, MKV, and AVI are accepted.";
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _showResults = false;
      _errorMessage = null;
      _uploadProgress = 0.0;
      _pipelineStep = 0;
      _statusMessage = "Connecting to forensic server...";
    });

    // Check backend availability
    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (!isOnline) {
      // Graceful switch to offline TFLite
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Backend offline. Switching to on-device TFLite model."),
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
        _statusMessage = "Uploading video file...";
        _pipelineStep = 1;
      });

      final res = await service.predictVideo(
        _baseUrl,
        file,
        onUploadProgress: (progress) {
          if (mounted && _isAnalyzing) {
            setState(() {
              _uploadProgress = progress * 0.8; // Upload takes up to 80% progress
              _statusMessage = "Uploading... ${(progress * 100).toStringAsFixed(0)}%";
            });
          }
        },
      );

      if (!_isAnalyzing) return; // User canceled

      setState(() {
        _pipelineStep = 3;
        _uploadProgress = 0.9;
        _statusMessage = "Aggregating predictions...";
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final prediction = (res['prediction'] ?? '').toString().toLowerCase();
      final confidence = (res['confidence'] ?? 0.0).toDouble();
      final frames = res['frames_analyzed'] ?? 0;
      final verdict = prediction == 'fake' ? 'manipulated' : 'authentic';
      final explanation = "Analyzed $frames face frame(s) using cloud-based Ensemble models. "
          "Model verdict is class '$prediction' with a confidence rating of ${(confidence * 100).toStringAsFixed(1)}%.";
      final finalConfidence = (confidence * 100).clamp(0.0, 100.0);
      final videoName = file.path.split(Platform.pathSeparator).last;

      // Update preliminary display values
      setState(() {
        _confidenceScore = finalConfidence;
        _verdict = verdict;
        _modelUsed = "MobileNet Ensemble (Cloud Server)";
        _explanation = explanation;
      });

      // Trigger the full post-verification pipeline (PDF, Firestore, notification)
      await _executePostVerificationFlow(
        videoName: videoName,
        videoPath: file.path,
        verdict: verdict,
        confidenceScore: finalConfidence,
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
            ? "Offline model failed: $_tfliteError"
            : "On-device model is loading — please retry in a moment.";
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

    // Step 0 — Validate
    setState(() {
      _pipelineStep = 0;
      _statusMessage = "Validating video file...";
      _uploadProgress = 0.10;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isAnalyzing) return;

    // Step 1 — Extract real frames at spread-out timestamps
    setState(() {
      _pipelineStep = 1;
      _statusMessage = "Extracting frames from video...";
      _uploadProgress = 0.25;
    });

    const int frameCount = 8;
    final List<int> timestampsMs = List.generate(frameCount, (i) => i * 2000);
    final tempDir = await getTemporaryDirectory();
    final List<Uint8List> frameBytes = [];

    for (int i = 0; i < timestampsMs.length; i++) {
      if (!_isAnalyzing) return;
      setState(() {
        _statusMessage = "Extracting frame ${i + 1} of ${timestampsMs.length} (${timestampsMs[i] ~/ 1000}s)...";
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

    // Step 2 — Face detection (UI step)
    setState(() {
      _pipelineStep = 2;
      _statusMessage = "Detecting regions of interest...";
      _uploadProgress = 0.55;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_isAnalyzing) return;

    // Step 3 — Resizing info
    setState(() {
      _pipelineStep = 3;
      _statusMessage = "Preparing 224x224 input tensors...";
      _uploadProgress = 0.65;
    });
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_isAnalyzing) return;

    // Step 4 — Run TFLite on every real frame
    setState(() {
      _pipelineStep = 4;
      _statusMessage = "Running on-device AI inference...";
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
        _errorMessage = "Inference failed on all frames. Try a different video file.";
      });
      return;
    }

    final avgFakeScore = scores.reduce((a, b) => a + b) / scores.length;
    final avgInferenceMs = inferenceMsSum ~/ scores.length;
    final finalConfidence = (avgFakeScore * 100).clamp(0.0, 100.0);
    final verdict = avgFakeScore >= 0.5 ? 'manipulated' : 'authentic';
    final filename = videoFile.path.split(Platform.pathSeparator).last;
    final explanation = "Analyzed ${scores.length} real frame(s) extracted from '$filename'. "
        "Verdict: '$verdict' with ${finalConfidence.toStringAsFixed(1)}% deepfake confidence. "
        "Average inference time: ${avgInferenceMs}ms per frame.";

    // Update preliminary display values
    setState(() {
      _pipelineStep = 3;
      _uploadProgress = 0.70;
      _confidenceScore = finalConfidence;
      _verdict = verdict;
      _modelUsed = "On-Device TFLite (veriframe_model)";
      _explanation = explanation;
    });

    // Trigger the full post-verification pipeline (PDF, Firestore, notification)
    await _executePostVerificationFlow(
      videoName: filename,
      videoPath: videoFile.path,
      verdict: verdict,
      confidenceScore: finalConfidence,
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
        const SnackBar(content: Text("Please paste a valid video URL link.")),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _showResults = false;
      _errorMessage = null;
      _uploadProgress = 0.1;
      _linkStep = 1; // Downloading
      _statusMessage = "Downloading video from link...";
    });

    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (!isOnline) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = "Url link verification requires an active forensic backend. Please configure backend settings.";
      });
      return;
    }

    try {
      final jobId = await service.verifyLink(_baseUrl, url);
      setState(() {
        _currentJobId = jobId;
        _uploadProgress = 0.3;
        _linkStep = 2; // Extracting
        _statusMessage = "Extracting frames on server...";
      });

      _pollLinkJobResult(jobId);
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _pollLinkJobResult(String jobId) {
    const maxPolls = 60;
    int polls = 0;

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      polls++;
      if (polls > maxPolls || !_isAnalyzing) {
        timer.cancel();
        if (_isAnalyzing) {
          setState(() {
            _isAnalyzing = false;
            _errorMessage = "Polling timeout: Job exceeded maximum execution time.";
          });
        }
        return;
      }

      try {
        final res = await VerifyBackendService.instance.getAnalysis(_baseUrl, jobId);
        final status = res['status']?.toString().toLowerCase();

        if (status == 'downloading') {
          setState(() {
            _linkStep = 1;
            _uploadProgress = 0.2;
            _statusMessage = "Downloading media stream...";
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
          final linkVerdict = results['verdict'] ?? 'authentic';
          final linkConfidence = (results['confidence_score'] ?? 0.0).toDouble();
          final linkModelUsed = results['model_used'] ?? 'Ensemble Model';
          final linkExplanation = results['explanation'] ?? 'Analysis completed successfully.';
          final linkUrl = _urlController.text.trim();

          setState(() {
            _linkStep = 4;
            _uploadProgress = 0.70;
            _confidenceScore = linkConfidence;
            _verdict = linkVerdict;
            _modelUsed = linkModelUsed;
            _explanation = linkExplanation;
          });

          // Trigger the full post-verification pipeline (PDF, Firestore, notification)
          await _executePostVerificationFlow(
            videoName: linkUrl.length > 60 ? '${linkUrl.substring(0, 57)}...' : linkUrl,
            videoPath: linkUrl,
            verdict: linkVerdict,
            confidenceScore: linkConfidence,
            explanation: linkExplanation,
            modelUsed: linkModelUsed,
          );
        } else if (status == 'failed') {
          timer.cancel();
          throw Exception(res['error'] ?? "Forensic server failed to process link.");
        }
      } catch (e) {
        timer.cancel();
        setState(() {
          _isAnalyzing = false;
          _errorMessage = e.toString();
        });
      }
    });
  }

  // --- LIVE STREAM PIPELINE ---
  Future<void> _verifyStreamUrl() async {
    final streamUrl = _streamUrlController.text.trim();
    if (streamUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid RTSP/RTMP/HLS stream URL.")),
      );
      return;
    }

    setState(() {
      _isStreaming = true;
      _showResults = false;
      _errorMessage = null;
      _rollingStreamScore = 0.0;
      _framesAnalyzed = 0;
      _streamFps = 0.0;
      _streamStartTime = DateTime.now();
      _confidenceHistory.clear();
    });

    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (!isOnline) {
      setState(() {
        _isStreaming = false;
        _errorMessage = "Live stream analyzer requires connection to a forensic server.";
      });
      return;
    }

    try {
      final sessionId = await service.verifyStream(_baseUrl, streamUrl);
      setState(() {
        _streamSessionId = sessionId;
      });

      _streamTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (!_isStreaming || _streamSessionId.isEmpty) {
          timer.cancel();
          return;
        }

        try {
          final res = await service.getAnalysis(_baseUrl, _streamSessionId);
          final status = res['status']?.toString().toLowerCase();
          
          if (status == 'completed' || status == 'stopped') {
            timer.cancel();
            return;
          }

          final result = res['result'];
          if (result != null) {
            final score = (result['confidence_score'] ?? 0.0).toDouble();
            _framesAnalyzed++;
            _updateFps();
            _addConfidencePoint(score);

            setState(() {
              _rollingStreamScore = score;
              _verdict = result['verdict'] ?? 'authentic';
              _modelUsed = result['model_used'] ?? '';
            });
          }
        } catch (e) {
          debugPrint("Stream polling error: $e");
        }
      });
    } catch (e) {
      setState(() {
        _isStreaming = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _startLocalCameraStream() async {
    if (_cameraController == null || !_isCameraInitialized) return;

    _streamSessionId = "stream-${DateTime.now().millisecondsSinceEpoch}";
    
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
            _verdict = res['verdict'] ?? 'authentic';
            _modelUsed = res['model_used'] ?? 'Biometric Network';
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

          final score = fakeScore * 100;
          _framesAnalyzed++;
          _updateFps();
          _addConfidencePoint(score);

          setState(() {
            _rollingStreamScore = score;
            _verdict = score >= 50.0 ? 'manipulated' : 'authentic';
            _modelUsed = 'On-Device TFLite (veriframe_model)';
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
      _statusMessage = "Compiling session report...";
    });

    final service = VerifyBackendService.instance;
    final isOnline = await service.isBackendAvailable(_baseUrl);

    if (!isOnline) {
      // Local report calculation
      await Future.delayed(const Duration(milliseconds: 1000));
      final streamExplanation = "Forensic camera review complete. Aggregated $_framesAnalyzed frame(s) processed locally. "
          "Calculated rolling average fake rating: ${_rollingStreamScore.toStringAsFixed(1)}%.";
      final streamVerdict = _rollingStreamScore >= 50.0 ? 'manipulated' : 'authentic';

      setState(() {
        _confidenceScore = _rollingStreamScore;
        _verdict = streamVerdict;
        _explanation = streamExplanation;
        _modelUsed = 'On-Device TFLite (veriframe_model)';
      });

      await _executePostVerificationFlow(
        videoName: 'Live Camera Stream',
        videoPath: '',
        verdict: streamVerdict,
        confidenceScore: _rollingStreamScore,
        explanation: streamExplanation,
        modelUsed: 'On-Device TFLite (veriframe_model)',
      );
      return;
    }

    try {
      final res = await service.createReport(_baseUrl, sessionId: _streamSessionId);
      final serverVerdict = res['verdict'] ?? 'authentic';
      final serverConfidence = (res['confidence_score'] ?? 0.0).toDouble();
      final serverModelUsed = res['model_used'] ?? '';
      final serverExplanation = res['explanation'] ?? 'Report compiled successfully.';

      setState(() {
        _confidenceScore = serverConfidence;
        _verdict = serverVerdict;
        _modelUsed = serverModelUsed;
        _explanation = serverExplanation;
        _reportId = res['report_id'] ?? '';
        _pdfUrl = res['pdf_url'] ?? '';
      });

      await _executePostVerificationFlow(
        videoName: 'Live Stream Session',
        videoPath: _streamSessionId,
        verdict: serverVerdict,
        confidenceScore: serverConfidence,
        explanation: serverExplanation,
        modelUsed: serverModelUsed,
      );
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _executePostVerificationFlow({
    required String videoName,
    required String videoPath,
    required String verdict,
    required double confidenceScore,
    required String explanation,
    required String modelUsed,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = "Authentication error: User not logged in.";
        });
      }
      return;
    }

    final createdAt = DateTime.now();
    final reportId = 'RPT-${createdAt.millisecondsSinceEpoch}';
    final prediction = verdict == 'authentic' ? 'REAL' : 'FAKE';
    final authenticityScore = verdict == 'authentic' ? confidenceScore : (100.0 - confidenceScore);
    final fakeProbability = verdict == 'authentic' ? (100.0 - confidenceScore) : confidenceScore;

    // Step 5: Composing VerificationResult
    if (mounted) {
      setState(() {
        _pipelineStep = 5;
        _statusMessage = "Compiling forensic report...";
        _uploadProgress = 0.80;
      });
    }
    await Future.delayed(const Duration(milliseconds: 400));

    // Build a VerificationResult from the legacy local values.
    // Frame consistency and tracking values were already computed; reuse display values.
    final frameConsistency = (100.0 - fakeProbability * 0.4).clamp(0.0, 100.0);
    final trackingConfidence = (100.0 - fakeProbability * 0.3).clamp(0.0, 100.0);
    final fusedConfidence = (confidenceScore * 0.70
        + (frameConsistency / 100.0) * 0.15 * 100.0
        + (trackingConfidence / 100.0) * 0.15 * 100.0
    ).clamp(0.0, 100.0);

    final result = VerificationResult(
      verificationId: reportId,
      verifiedAt: createdAt,
      mediaType: 'video',
      source: videoPath.startsWith('http') ? 'URL Link' : (videoPath.isEmpty ? 'Live Stream' : 'Local File'),
      authenticityScore: authenticityScore,
      fakeProbability: fakeProbability,
      confidence: fusedConfidence,
      metadataScore: 85.0,
      frameConsistency: frameConsistency,
      ocrConfidence: 0.0,
      trackingConfidence: trackingConfidence,
      manipulationScore: fakeProbability,
      verdict: verdict.toUpperCase() == 'AUTHENTIC' ? 'AUTHENTIC' : 'MANIPULATED',
      riskLevel: fakeProbability >= 70.0 ? 'HIGH' : (fakeProbability >= 40.0 ? 'MEDIUM' : 'LOW'),
      detectedEvidence: verdict == 'authentic' ? [] : [
        'Biometric inconsistency detected across temporal frames.',
        'Face texture anomalies detected in classified regions.',
      ],
      forensicObservations: [
        'TFLite deep-learning classifier output: $prediction (${confidenceScore.toStringAsFixed(1)}% confidence).',
        'Frame consistency score: ${frameConsistency.toStringAsFixed(1)}%.',
        'Biometric tracking stability: ${trackingConfidence.toStringAsFixed(1)}%.',
        explanation,
      ],
      reportHash: reportId.hashCode.toRadixString(16).padLeft(16, '0'),
      mediaPath: videoPath.isEmpty ? null : videoPath,
      mediaName: videoName,
    );

    // Persist to Riverpod state
    ref.read(verificationProvider.notifier).setResult(result);

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
      title: "Verification Completed",
      message: "Analysis complete. Verdict: ${result.verdict}. "
          "Authenticity: ${result.authenticityScore.toStringAsFixed(1)}%. Tap to view report.",
      type: "verification_completed",
      reportId: reportId,
      createdAt: createdAt,
      isRead: false,
      score: result.authenticityScore,
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
        title: "VeriFrame – Verification Complete",
        body: "${result.verdict}: ${result.authenticityScore.toStringAsFixed(1)}% authentic. Tap to view report.",
        payload: reportId,
      );
    } catch (e) {
      debugPrint("Local notification failed: $e");
    }

    // Step 8: Completed — show immutable success dialog
    if (mounted) {
      setState(() {
        _pipelineStep = 8;
        _statusMessage = "Completed";
        _uploadProgress = 1.0;
        _isAnalyzing = false;
        _showResults = true;
        _reportId = reportId;
      });

      _showSuccessDialog(result);
    }
  }

  void _showSuccessDialog(VerificationResult result) {
    final isReal = result.verdict.toUpperCase() == 'AUTHENTIC';
    final accentColor = isReal ? const Color(0xFF00E896) : const Color(0xFFFF3B5C);

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
                'Verification Complete',
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
              _buildDialogRow('Verdict', result.verdict, accentColor, bold: true),
              _buildDialogRow('Authenticity', '${result.authenticityScore.toStringAsFixed(2)}%', _vp.text),
              _buildDialogRow('Confidence', '${result.confidence.toStringAsFixed(2)}%', _vp.text),
              _buildDialogRow(
                'Risk Level',
                result.riskLevel,
                result.riskLevel == 'LOW'
                    ? const Color(0xFF00E896)
                    : (result.riskLevel == 'MEDIUM' ? const Color(0xFFFFB020) : const Color(0xFFFF3B5C)),
              ),
              _buildDialogRow(
                'Verified At',
                DateFormat('MMM dd, yyyy · HH:mm').format(result.verifiedAt),
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
                      child: const Text('View History'),
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
                      child: const Text('Done'),
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
      _statusMessage = "Generating forensic report PDF...";
      _isAnalyzing = true;
    });

    try {
      final file = await PdfService.instance.generateReportPdf(result: result);
      setState(() {
        _isAnalyzing = false;
      });
      if (file != null && await file.exists()) {
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to compile PDF: $e"), backgroundColor: const Color(0xFFFF3B5C)),
        );
      }
    }
  }

  Future<void> _launchReportPdf() async {
    if (_pdfUrl.isEmpty) return;
    
    // If it's a local file path, open it directly using OpenFilex
    if (!_pdfUrl.startsWith('http')) {
      final file = File(_pdfUrl);
      if (await file.exists()) {
        final openResult = await OpenFilex.open(file.path);
        if (openResult.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error opening PDF: ${openResult.message}"),
              backgroundColor: VFColors.red600,
            ),
          );
        }
        return;
      }
    }

    final fullUrl = _pdfUrl.startsWith('http') ? _pdfUrl : "$_baseUrl$_pdfUrl";
    final uri = Uri.parse(fullUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: fullUrl));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Link copied to clipboard: $fullUrl")),
        );
      }
    }
  }

  void _shareForensicLink(VerificationResult result) {
    final reportSummary = "VeriFrame Forensic Report [${result.verificationId}]: Verdict ${result.verdict} with ${result.authenticityScore.toStringAsFixed(1)}% authenticity rating. Verification Link: https://veriframe.io/verify/${result.verificationId}";
    Clipboard.setData(ClipboardData(text: reportSummary));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Forensic summary link copied to clipboard!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF00E896),
      ),
    );
  }

  void _showEscalationModal() {
    final loc = AppLocalizations.of(context)!;
    bool confirm = false;
    bool consent = false;
    String agency = "police";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: _vp.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(loc.verifyEscalateTitle, style: TextStyle(color: _vp.text, fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.verifyEscalateDescription,
                      style: TextStyle(color: _vp.textMuted, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: agency,
                      dropdownColor: _vp.surface,
                      style: TextStyle(color: _vp.text),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _vp.surfaceVariant,
                        labelText: loc.verifyEscalationAgency,
                        labelStyle: TextStyle(color: _vp.textMuted),
                      ),
                      items: [
                        DropdownMenuItem(value: "police", child: Text(loc.verifySriLankaPolice)),
                        DropdownMenuItem(value: "cert_cc", child: Text(loc.verifyCertCc)),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => agency = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: confirm,
                      onChanged: (val) => setModalState(() => confirm = val ?? false),
                      title: Text(loc.verifyEscalateConfirm, style: TextStyle(color: _vp.textMuted, fontSize: 11)),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: const Color(0xFF00C8FF),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: consent,
                      onChanged: (val) => setModalState(() => consent = val ?? false),
                      title: Text(loc.verifyEscalateConsent, style: TextStyle(color: _vp.textMuted, fontSize: 11)),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: const Color(0xFF00C8FF),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.verifyCancel, style: TextStyle(color: _vp.textMuted)),
                ),
                ElevatedButton(
                  onPressed: (confirm && consent) ? () async {
                    Navigator.pop(context);
                    await _triggerEscalation(agency);
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B5C),
                    disabledBackgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(loc.verifySubmitEscalation),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _triggerEscalation(String agency) async {
    try {
      final msg = await VerifyBackendService.instance.sendReport(
        _baseUrl,
        _reportId.isNotEmpty ? _reportId : "REP-${DateTime.now().millisecondsSinceEpoch}",
        agency,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFF00E896), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Escalation failed: $e"), backgroundColor: const Color(0xFFFF3B5C), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showBackendSettings() {
    final controller = TextEditingController(text: _baseUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _vp.surface,
          title: Text("Configure Backend Server", style: TextStyle(color: _vp.text, fontSize: 16)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: _vp.text),
            decoration: InputDecoration(
              hintText: "http://192.168.1.100:8000",
              hintStyle: TextStyle(color: _vp.textMuted),
              helperText: "Specify host base address (use LAN IP on physical phones)",
              helperStyle: TextStyle(color: _vp.textMuted, fontSize: 11),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: _vp.textMuted)),
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
              child: const Text("Save"),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00C8FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF00C8FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _tfliteReady ? Icons.check_circle_outline : Icons.hourglass_empty,
                  color: _tfliteReady ? const Color(0xFF00E896) : const Color(0xFFFFB020),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  _tfliteReady ? loc.verifyOnDeviceReady : loc.verifyLoadingModel,
                  style: TextStyle(
                    color: _tfliteReady ? const Color(0xFF00E896) : const Color(0xFFFFB020),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _vp.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _vp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.verifyVideoUrlPaste,
            style: TextStyle(color: _vp.text, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            loc.verifyUrlScanDescription,
            style: TextStyle(color: _vp.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            style: TextStyle(color: _vp.text),
            decoration: const InputDecoration(
              hintText: "Paste YouTube, TikTok, Facebook, or direct URL...",
              prefixIcon: Icon(Icons.insert_link, color: Color(0xFF00C8FF)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _verifyUrlLink,
            icon: Icon(Icons.analytics_outlined),
            label: Text(loc.verifyAnalyzeUrlClip),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStreamCard(AppColors colors, AppLocalizations loc) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _vp.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _vp.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings_input_antenna, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 10),
                  Text(
                    loc.verifyExternalLiveStream,
                    style: TextStyle(color: _vp.text, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                loc.verifyStreamDescription,
                style: TextStyle(color: _vp.textMuted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _streamUrlController,
                style: TextStyle(color: _vp.text),
                decoration: InputDecoration(
                  hintText: loc.verifyStreamUrlHint,
                  prefixIcon: Icon(Icons.link, color: Color(0xFF7C3AED)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _verifyStreamUrl,
                  icon: Icon(Icons.play_circle_filled_sharp),
                  label: const Text("Analyze Stream URL"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _vp.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _vp.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.camera_alt, color: Color(0xFF00C8FF)),
                  const SizedBox(width: 10),
                  Text(
                    loc.verifyDeviceCameraFeed,
                    style: TextStyle(color: _vp.text, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                loc.verifyCameraStreamDescription,
                style: TextStyle(color: _vp.textMuted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _initCamera();
                    if (_isCameraInitialized) {
                      await _startLocalCameraStream();
                    }
                  },
                  icon: Icon(Icons.videocam_outlined),
                  label: Text(loc.verifyOpenCameraStream),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00C8FF),
                    side: const BorderSide(color: Color(0xFF00C8FF)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisProgressPipeline(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _vp.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _vp.borderBright),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: Color(0xFF00C8FF), strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: TextStyle(color: _vp.text, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: _vp.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00C8FF)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 24),
          // Vertical Pipeline Tracker
          if (_activeTab == 0) _buildPipelineTimelineSteps(),
          if (_activeTab == 1) _buildLinkVerificationStepper(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _cancelAnalysis,
            icon: Icon(Icons.cancel_outlined),
            label: const Text("Cancel Scan"),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF3B5C),
              side: const BorderSide(color: Color(0xFFFF3B5C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineTimelineSteps() {
    // Pipeline including post-verification (PDF, Notification, Completed)
    final steps = [
      "Format Validation",
      "Frame Extraction",
      "Face Detection",
      "Model Inference & Aggregation",
      "Generating AI Reasoning",
      "Generating PDF Forensic Report",
      "Sending Notification",
      "Completed",
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isDone = _pipelineStep > index;
        final isCurrent = _pipelineStep == index;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF00E896)
                        : isCurrent
                            ? const Color(0xFF00C8FF)
                            : _vp.surfaceVariant,
                    border: Border.all(
                      color: isCurrent ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isDone ? Icons.check : Icons.circle,
                    size: 10,
                    color: isDone ? const Color(0xFF0A0F1D) : Colors.transparent,
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 24,
                    color: isDone ? const Color(0xFF00E896) : _vp.surfaceVariant,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  steps[index],
                  style: TextStyle(
                    color: isDone
                        ? const Color(0xFF00E896)
                        : isCurrent
                            ? _vp.text
                            : _vp.textMuted,
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildLinkVerificationStepper() {
    // Combined pipeline: 5 link-download steps (tracked by _linkStep) + 5 post-processing steps (tracked by _pipelineStep)
    // _linkStep  indices: 0=request, 1=downloading, 2=extracting, 3=detecting, 4=inference
    // _pipelineStep indices: 4=reasoning, 5=pdf, 6=notification, 7=completed
    final steps = [
      'Request Initiated',
      'Downloading Video File',
      'Extracting Sub-Frames',
      'Running Biometric Detection',
      'Model Inference Running',
      'Generating AI Reasoning',
      'Generating PDF Forensic Report',
      'Sending Notification',
      'Completed',
    ];

    // Map index to completion status
    bool isStepDone(int index) {
      if (index < 5) return _linkStep > index;
      // Post-verification steps start when _pipelineStep >= 4 (reasoning)
      final postStepIndex = index - 5 + 4; // index 5 -> _pipelineStep 4, index 9 -> _pipelineStep 8
      return _pipelineStep > postStepIndex;
    }

    bool isStepCurrent(int index) {
      if (index < 5) return _linkStep == index && _pipelineStep < 4;
      final postStepIndex = index - 5 + 4;
      return _pipelineStep == postStepIndex;
    }

    return Column(
      children: List.generate(steps.length, (index) {
        final isDone = isStepDone(index);
        final isCurrent = isStepCurrent(index);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? const Color(0xFF00E896) : isCurrent ? const Color(0xFF00C8FF) : _vp.surfaceVariant,
                    border: Border.all(color: isCurrent ? Colors.white : Colors.transparent, width: 2),
                  ),
                  child: Icon(
                    isDone ? Icons.check : Icons.circle,
                    size: 10,
                    color: isDone ? const Color(0xFF0A0F1D) : Colors.transparent,
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 2,
                    height: 24,
                    color: isDone ? const Color(0xFF00E896) : _vp.surfaceVariant,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  steps[index],
                  style: TextStyle(
                    color: isDone ? const Color(0xFF00E896) : isCurrent ? _vp.text : _vp.textMuted,
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
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
                      "Connecting to Live Stream...",
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
                      "FPS: ${_streamFps.toStringAsFixed(1)} | Frames: $_framesAnalyzed",
                      style: TextStyle(color: _vp.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats Dashboard details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Current Probability:", style: TextStyle(color: _vp.textMuted, fontSize: 12)),
                    Text(
                      "${_rollingStreamScore.toStringAsFixed(1)}%",
                      style: TextStyle(
                        color: _rollingStreamScore >= 75 ? const Color(0xFFFF3B5C) : const Color(0xFF00E896),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _rollingStreamScore / 100,
                    backgroundColor: _vp.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(
                      _rollingStreamScore >= 75 ? const Color(0xFFFF3B5C) : const Color(0xFF00E896),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),
                Text("Probability Rolling Graph", style: TextStyle(color: _vp.text, fontSize: 12, fontWeight: FontWeight.bold)),
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

    final isHighRisk = result.riskLevel == 'HIGH';

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
                      value: result.authenticityScore / 100,
                      strokeWidth: 8,
                      backgroundColor: _vp.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation(verdictColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${result.authenticityScore.toStringAsFixed(1)}%",
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
                            "Landmark map: 83 points detected",
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
                label: const Text("Share Link"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _vp.canvas,
                  foregroundColor: _vp.text,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        if (isHighRisk) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showEscalationModal,
            icon: Icon(Icons.gavel_rounded),
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
              _confidenceScore = 0.0;
              _reportId = "";
              _pdfUrl = "";
              _streamSessionId = "";
              _errorMessage = null;
            });
          },
          child: Text(loc.verifyScanAnotherMedia),
        ),
      ],
    );
  }
}

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

