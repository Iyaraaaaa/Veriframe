import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:veriframe_app/screens/verify.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class CameraStreamScreen extends StatefulWidget {
  final String? streamUrl;

  const CameraStreamScreen({super.key, this.streamUrl});

  @override
  State<CameraStreamScreen> createState() => _CameraStreamScreenState();
}

class _CameraStreamScreenState extends State<CameraStreamScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isStreaming = false;
  String? _error;
  int _framesCaptured = 0;
  final List<String> _capturedFrames = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'no_cameras');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'camera_error');
      }
    }
  }

  Future<void> _startStreaming() async {
    if (_controller == null || !_isInitialized) return;
    setState(() => _isStreaming = true);
    _capturedFrames.clear();
    _framesCaptured = 0;

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isStreaming || !mounted) {
        timer.cancel();
        return;
      }
      try {
        final file = await _controller!.takePicture();
        setState(() {
          _framesCaptured++;
          _capturedFrames.add(file.path);
        });
      } catch (_) {
        timer.cancel();
      }
    });
  }

  Future<void> _stopStreaming() async {
    setState(() => _isStreaming = false);
    if (_capturedFrames.isNotEmpty && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyPage(
            initialVideoPath: _capturedFrames.last,
            initialStreamUrl: widget.streamUrl,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _buildErrorView(loc)
            : !_isInitialized
                ? _buildLoadingView(loc)
                : Column(
                    children: [
                      Expanded(child: CameraPreview(_controller!)),
                      if (_isStreaming)
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.black54,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.cameraLiveStreamFrames(_framesCaptured),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _stopStreaming,
                                icon: const Icon(Icons.stop),
                                label: Text(loc.cameraStopAnalyze),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF3B5C),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          color: Colors.black54,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _startStreaming,
                              icon: const Icon(Icons.play_arrow),
                              label: Text(loc.cameraStartLiveStream),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C8FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorView(AppLocalizations loc) {
    final errorMessage = _error == 'no_cameras'
        ? loc.cameraNoCamerasFound
        : _error == 'camera_error'
            ? loc.cameraError('')
            : _error ?? '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cameraGoBack),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00C8FF)),
          const SizedBox(height: 16),
          Text(
            loc.cameraInitializing,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
