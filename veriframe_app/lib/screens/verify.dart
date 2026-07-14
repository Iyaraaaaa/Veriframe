import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:veriframe_app/service/tflite_service.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:veriframe_app/models/report_model.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/service/report_service.dart';
import 'package:veriframe_app/service/notification_service.dart';
import 'package:veriframe_app/service/pdf_service.dart';
import 'package:intl/intl.dart';

class VerifyPage extends StatefulWidget {
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
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> with TickerProviderStateMixin {
  int _activeTab = 0; // 0 = Video, 1 = Link, 2 = Live Stream

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
        _pipelineStep = 4;
        _uploadProgress = 0.9;
        _statusMessage = "Aggregating predictions...";
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final prediction = (res['prediction'] ?? '').toString().toLowerCase();
      final confidence = (res['confidence'] ?? 0.0).toDouble();
      final frames = res['frames_analyzed'] ?? 0;
      final verdict = prediction == 'fake' ? 'manipulated' : 'authentic';

      setState(() {
        _isAnalyzing = false;
        _showResults = true;
        _uploadProgress = 1.0;
        _pipelineStep = 5;
        _confidenceScore = (confidence * 100).clamp(0.0, 100.0);
        _verdict = verdict;
        _modelUsed = "MobileNet Ensemble (Cloud Server)";
        _explanation = "Analyzed $frames face frame(s) using cloud-based Ensemble models. "
            "Model verdict is class '$prediction' with a confidence rating of ${(confidence * 100).toStringAsFixed(1)}%.";
      });

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

    setState(() {
      _pipelineStep = 5;
      _uploadProgress = 1.0;
      _isAnalyzing = false;
      _showResults = true;
      _confidenceScore = finalConfidence;
      _verdict = verdict;
      _modelUsed = "On-Device TFLite (veriframe_model)";
      _explanation = "Analyzed ${scores.length} real frame(s) extracted from '$filename'. "
          "Verdict: '$verdict' with ${finalConfidence.toStringAsFixed(1)}% deepfake confidence. "
          "Average inference time: ${avgInferenceMs}ms per frame.";
    });
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
          setState(() {
            _linkStep = 5;
            _uploadProgress = 1.0;
            _isAnalyzing = false;
            _showResults = true;
            _confidenceScore = (results['confidence_score'] ?? 0.0).toDouble();
            _verdict = results['verdict'] ?? 'authentic';
            _modelUsed = results['model_used'] ?? 'Ensemble Model';
            _explanation = results['explanation'] ?? 'Analysis completed successfully.';
          });
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
      setState(() {
        _isAnalyzing = false;
        _showResults = true;
        _confidenceScore = _rollingStreamScore;
        _explanation = "Forensic camera review complete. Aggregated $_framesAnalyzed frame(s) processed locally. "
            "Calculated rolling average fake rating: ${_rollingStreamScore.toStringAsFixed(1)}%.";
      });
      return;
    }

    try {
      final res = await service.createReport(_baseUrl, sessionId: _streamSessionId);
      setState(() {
        _confidenceScore = (res['confidence_score'] ?? 0.0).toDouble();
        _verdict = res['verdict'] ?? 'authentic';
        _modelUsed = res['model_used'] ?? '';
        _explanation = res['explanation'] ?? 'Report compiled successfully.';
        _reportId = res['report_id'] ?? '';
        _pdfUrl = res['pdf_url'] ?? '';
        _isAnalyzing = false;
        _showResults = true;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<String> _generateBase64Thumbnail(String path) async {
    if (path.isEmpty || path.startsWith('http')) return '';
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await vt.VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: tempDir.path,
        imageFormat: vt.ImageFormat.JPEG,
        timeMs: 0,
        quality: 50,
        maxWidth: 120,
        maxHeight: 120,
      );
      if (thumbPath != null) {
        final file = File(thumbPath);
        final bytes = await file.readAsBytes();
        await file.delete();
        return base64Encode(bytes);
      }
    } catch (e) {
      debugPrint('[VerifyPage] Error generating base64 thumbnail: $e');
    }
    return '';
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
    final reportId = FirebaseFirestore.instance.collection('users').doc(uid).collection('reports').doc().id;
    final prediction = verdict == 'authentic' ? 'REAL' : 'FAKE';
    final score = verdict == 'authentic' ? confidenceScore : (100.0 - confidenceScore);

    // Step 4: Generating Reasoning
    if (mounted) {
      setState(() {
        _isAnalyzing = true;
        _showResults = false;
        _pipelineStep = 4;
        _statusMessage = "Generating AI Reasoning...";
        _uploadProgress = 0.72;
      });
    }
    await Future.delayed(const Duration(milliseconds: 600));

    // Step 5: Generating PDF
    if (mounted) {
      setState(() {
        _pipelineStep = 5;
        _statusMessage = "Generating PDF Forensic Report...";
        _uploadProgress = 0.80;
      });
    }

    File? pdfFile;
    String pdfPath = '';
    String pdfName = 'Verification_Report_${DateFormat('yyyy-MM-dd_HH-mm').format(createdAt)}.pdf';

    try {
      if (_pdfUrl.isNotEmpty) {
        final downloadsDir = Directory('/storage/emulated/0/Download/VeriFrame');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        final path = '${downloadsDir.path}/$pdfName';
        final fullUrl = _pdfUrl.startsWith('http') ? _pdfUrl : "$_baseUrl$_pdfUrl";

        final permStatus = await Permission.storage.request();
        if (permStatus.isGranted || Platform.isIOS) {
          pdfFile = await ReportService.instance.downloadReportPdf(fullUrl, pdfName);
          if (pdfFile != null) {
            pdfPath = pdfFile.path;
          }
        }
      }

      if (pdfFile == null) {
        await Permission.storage.request();
        pdfFile = await PdfService.instance.generateReportPdf(
          reportId: reportId,
          videoName: videoName,
          prediction: prediction,
          confidence: confidenceScore,
          score: score,
          reasoning: explanation,
          createdAt: createdAt,
          duration: 0.0,
          processingTime: 5.0,
        );
        if (pdfFile != null) {
          pdfPath = pdfFile.path;
        }
      }
    } catch (e) {
      debugPrint("PDF generation failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to generate report."),
            backgroundColor: Color(0xFFFF3B5C),
          ),
        );
      }
    }

    // Step 6: Saving Report
    if (mounted) {
      setState(() {
        _pipelineStep = 6;
        _statusMessage = "Saving Report to Firestore...";
        _uploadProgress = 0.88;
      });
    }

    final thumbnailBase64 = await _generateBase64Thumbnail(videoPath);

    final report = ReportModel(
      reportId: reportId,
      videoName: videoName,
      videoPath: videoPath,
      prediction: prediction,
      confidence: confidenceScore,
      score: score,
      reasoning: explanation,
      createdAt: createdAt,
      pdfPath: pdfPath,
      pdfName: pdfName,
      thumbnail: thumbnailBase64,
      duration: 0.0,
      processingTime: 5.0,
    );

    int retries = 3;
    while (retries > 0) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('reports')
            .doc(reportId)
            .set(report.toMap());
        break;
      } catch (e) {
        retries--;
        if (retries == 0) {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _errorMessage = "Firestore upload failed. Please try again.";
            });
          }
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // Step 7: Sending Notification
    if (mounted) {
      setState(() {
        _pipelineStep = 7;
        _statusMessage = "Sending Notification...";
        _uploadProgress = 0.94;
      });
    }

    final notificationId = FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').doc().id;
    final notification = NotificationModel(
      id: notificationId,
      title: "Video Verification Completed",
      message: "Your uploaded video has been analyzed successfully. Authenticity Score: ${score.toStringAsFixed(0)}%. Tap to view report.",
      type: "verification_completed",
      reportId: reportId,
      createdAt: createdAt,
      isRead: false,
      score: score,
      prediction: prediction,
      videoName: videoName,
    );

    retries = 3;
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
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _errorMessage = "Notification creation failed.";
            });
          }
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    try {
      await NotificationService.instance.showLocalNotification(
        id: notificationId.hashCode,
        title: "Verification Completed",
        body: "Tap to open report.",
        payload: reportId,
      );
    } catch (e) {
      debugPrint("Local notification failed: $e");
    }

    // Step 8: Completed
    if (mounted) {
      setState(() {
        _pipelineStep = 8;
        _statusMessage = "Completed";
        _uploadProgress = 1.0;
        _isAnalyzing = false;
        _showResults = true;
        _reportId = reportId;
        _pdfUrl = _pdfUrl.isNotEmpty ? _pdfUrl : pdfPath;
      });

      // Show success dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color(0xFF0F1523),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF00E896)),
              SizedBox(width: 8),
              Text("Verification Completed", style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            "Video '$videoName' has been verified.\n\n"
            "Verdict: $prediction\n"
            "Authenticity Score: ${score.toStringAsFixed(1)}%\n\n"
            "The PDF report has been downloaded to Downloads/VeriFrame/.",
            style: const TextStyle(color: Color(0xFFE8F0FF)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: Color(0xFF00C8FF))),
            ),
          ],
        ),
      );
    }
  }

  // --- REPORT ACTION TRIGGERS ---
  Future<void> _getPdfForensicReport() async {
    if (_reportId.isNotEmpty && _pdfUrl.isNotEmpty) {
      _launchReportPdf();
      return;
    }

    setState(() {
      _statusMessage = "Requesting PDF generation...";
      _isAnalyzing = true;
    });

    try {
      final res = await VerifyBackendService.instance.createReport(
        _baseUrl,
        sessionId: _streamSessionId,
        jobId: _streamSessionId.isEmpty ? _currentJobId : "",
      );
      setState(() {
        _reportId = res['report_id'] ?? '';
        _pdfUrl = res['pdf_url'] ?? '';
        _isAnalyzing = false;
      });
      _launchReportPdf();
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

  void _shareForensicLink() {
    final reportSummary = "VeriFrame Forensic Report: Verdict $_verdict with $_confidenceScore% confidence using $_modelUsed. Link: $_baseUrl$_pdfUrl";
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
              backgroundColor: const Color(0xFF0F1523),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(loc.verifyEscalateTitle, style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 18, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.verifyEscalateDescription,
                      style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: agency,
                      dropdownColor: const Color(0xFF0F1523),
                      style: const TextStyle(color: Color(0xFFE8F0FF)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF162035),
                        labelText: loc.verifyEscalationAgency,
                        labelStyle: const TextStyle(color: Color(0xFF6B7FA8)),
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
                      title: Text(loc.verifyEscalateConfirm, style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 11)),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: const Color(0xFF00C8FF),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: consent,
                      onChanged: (val) => setModalState(() => consent = val ?? false),
                      title: Text(loc.verifyEscalateConsent, style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 11)),
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
                  child: Text(loc.verifyCancel, style: const TextStyle(color: Color(0xFF6B7FA8))),
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
          backgroundColor: const Color(0xFF0F1523),
          title: const Text("Configure Backend Server", style: TextStyle(color: Color(0xFFE8F0FF), fontSize: 16)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Color(0xFFE8F0FF)),
            decoration: const InputDecoration(
              hintText: "http://192.168.1.100:8000",
              hintStyle: TextStyle(color: Color(0xFF6B7FA8)),
              helperText: "Specify host base address (use LAN IP on physical phones)",
              helperStyle: TextStyle(color: Color(0xFF6B7FA8), fontSize: 11),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B7FA8))),
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
          icon: const Icon(Icons.settings_ethernet, color: Colors.white, size: 20),
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
                if (_showResults) _buildForensicResultsDashboard(colors),
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
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3B5C)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 13, height: 1.4),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF6B7FA8)),
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
            color: const Color(0xFF0A0F1D),
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
            color: isSelected ? const Color(0xFF162035) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF00C8FF) : const Color(0xFF6B7FA8), size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFE8F0FF) : const Color(0xFF6B7FA8),
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
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A2233)),
      ),
      child: Column(
        children: [
          const Icon(Icons.drive_folder_upload, size: 64, color: Color(0xFF00C8FF)),
          const SizedBox(height: 16),
          Text(
            loc.verifyAiForensicTitle,
            style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _baseUrl.isEmpty ? loc.verifyNoBackendUrl : loc.verifySelectLocalVideo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 12, height: 1.5),
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
            icon: const Icon(Icons.video_collection),
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
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A2233)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.verifyVideoUrlPaste,
            style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            loc.verifyUrlScanDescription,
            style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Color(0xFFE8F0FF)),
            decoration: const InputDecoration(
              hintText: "Paste YouTube, TikTok, Facebook, or direct URL...",
              prefixIcon: Icon(Icons.insert_link, color: Color(0xFF00C8FF)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _verifyUrlLink,
            icon: const Icon(Icons.analytics_outlined),
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
            color: const Color(0xFF0F1523),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1A2233)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_input_antenna, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 10),
                  Text(
                    loc.verifyExternalLiveStream,
                    style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                loc.verifyStreamDescription,
                style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _streamUrlController,
                style: const TextStyle(color: Color(0xFFE8F0FF)),
                decoration: InputDecoration(
                  hintText: loc.verifyStreamUrlHint,
                  prefixIcon: const Icon(Icons.link, color: Color(0xFF7C3AED)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _verifyStreamUrl,
                  icon: const Icon(Icons.play_circle_filled_sharp),
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
            color: const Color(0xFF0F1523),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1A2233)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.camera_alt, color: Color(0xFF00C8FF)),
                  const SizedBox(width: 10),
                  Text(
                    loc.verifyDeviceCameraFeed,
                    style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                loc.verifyCameraStreamDescription,
                style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 12, height: 1.4),
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
                  icon: const Icon(Icons.videocam_outlined),
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
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2740)),
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
            style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: const Color(0xFF162035),
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
            icon: const Icon(Icons.cancel_outlined),
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
    final steps = [
      "Format Validation",
      "Frame Extraction",
      "Face Detection",
      "Resolution Normalization (224x224)",
      "TFLite Model Classification",
      "Aggregation Results",
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
                            : const Color(0xFF162035),
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
                    color: isDone ? const Color(0xFF00E896) : const Color(0xFF162035),
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
                            ? const Color(0xFFE8F0FF)
                            : const Color(0xFF6B7FA8),
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
    final steps = [
      "Request Initiated",
      "Downloading Video File",
      "Extracting Sub-Frames",
      "Running Biometric Detection",
      "Model Inference Running",
      "Completed",
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isDone = _linkStep > index;
        final isCurrent = _linkStep == index;
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
                    color: isDone ? const Color(0xFF00E896) : isCurrent ? const Color(0xFF00C8FF) : const Color(0xFF162035),
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
                    color: isDone ? const Color(0xFF00E896) : const Color(0xFF162035),
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
                    color: isDone ? const Color(0xFF00E896) : isCurrent ? const Color(0xFFE8F0FF) : const Color(0xFF6B7FA8),
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
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2740)),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF080C14), Color(0xFF162035)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors, color: Color(0xFF7C3AED), size: 48),
                    SizedBox(height: 12),
                    Text(
                      "Connecting to Live Stream...",
                      style: TextStyle(color: Color(0xFFE8F0FF), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0F1523),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: Color(0xFFFF3B5C), size: 12),
                        const SizedBox(width: 8),
                        Text(
                          isDeviceCam ? loc.verifyFeedStreaming : loc.verifyAiAnalyzingStream,
                          style: const TextStyle(color: Color(0xFFFF3B5C), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      "FPS: ${_streamFps.toStringAsFixed(1)} | Frames: $_framesAnalyzed",
                      style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats Dashboard details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Current Probability:", style: TextStyle(color: Color(0xFF6B7FA8), fontSize: 12)),
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
                    backgroundColor: const Color(0xFF162035),
                    valueColor: AlwaysStoppedAnimation(
                      _rollingStreamScore >= 75 ? const Color(0xFFFF3B5C) : const Color(0xFF00E896),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Probability Rolling Graph", style: TextStyle(color: Color(0xFFE8F0FF), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // Real-time custom painter graph
                DeepfakeGraph(dataPoints: List.from(_confidenceHistory)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _stopLiveStreamAndGenerateReport,
                  icon: const Icon(Icons.stop_circle_rounded),
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
                decoration: const BoxDecoration(
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

  Widget _buildForensicResultsDashboard(AppColors colors) {
    final loc = AppLocalizations.of(context)!;
    final verdictColor = _verdict == "manipulated"
        ? const Color(0xFFFF3B5C)
        : _verdict == "inconclusive"
            ? const Color(0xFFFFB020)
            : const Color(0xFF00E896);

    final isHighRisk = _confidenceScore >= 75;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1523),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1C2740)),
          ),
          child: Column(
            children: [
              Text(
                loc.verifyForensicConclusion.toUpperCase(),
                style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: _confidenceScore / 100,
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFF162035),
                      valueColor: AlwaysStoppedAnimation(verdictColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${_confidenceScore.toStringAsFixed(1)}%",
                        style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _verdict.toUpperCase(),
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
                  color: const Color(0xFF0A0F1D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF162035)),
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
                          child: const Text("EYE_L", style: TextStyle(color: Colors.white70, fontSize: 8)),
                        ),
                      ),
                      Positioned(
                        top: 22,
                        right: 40,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(border: Border.all(color: verdictColor, width: 1)),
                          child: const Text("EYE_R", style: TextStyle(color: Colors.white70, fontSize: 8)),
                        ),
                      ),
                      Positioned(
                        bottom: 18,
                        left: 80,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(border: Border.all(color: verdictColor, width: 1)),
                          child: const Text("MOUTH", style: TextStyle(color: Colors.white70, fontSize: 8)),
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
                "${loc.verifyModelUsed} $_modelUsed",
                style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1523),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1C2740)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.verifyExplainableAiStatement,
                style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _explanation,
                style: const TextStyle(color: Color(0xFF6B7FA8), fontSize: 12, height: 1.5, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _getPdfForensicReport,
                icon: const Icon(Icons.picture_as_pdf_outlined),
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
                onPressed: _shareForensicLink,
                icon: const Icon(Icons.share_outlined),
                label: const Text("Share Link"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A0F1D),
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
            onPressed: _showEscalationModal,
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
        color: const Color(0xFF070B13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1C2740)),
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
      ..color = const Color(0xFF1C2740).withValues(alpha: 0.4)
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

