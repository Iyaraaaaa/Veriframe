import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:veriframe_app/service/frame_extractor.dart';
import 'package:veriframe_app/service/tflite_service.dart';

enum DeepFakeResultLabel { real, fake }

class DeepFakeInference {
  final DeepFakeResultLabel label;
  final double confidence;
  DeepFakeInference({required this.label, required this.confidence});
}

class DeepFakeProvider extends ChangeNotifier {
  bool _isProcessing = false;
  DeepFakeInference? _lastResult;

  bool get isProcessing => _isProcessing;
  DeepFakeInference? get lastResult => _lastResult;

  Future<void> processFile(File videoFile) async {
    _setProcessing(true);
    try {
      final frames = await FrameExtractor.extractFramesFromFile(videoFile);
      final result = await _runModel(frames);
      _setResult(result);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> processUrl(String url) async {
    _setProcessing(true);
    try {
      final frames = await FrameExtractor.extractFramesFromUrl(url);
      final result = await _runModel(frames);
      _setResult(result);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> processStream(Stream<Uint8List> thumbnailStream) async {
    _setProcessing(true);
    try {
      final frames = await FrameExtractor.extractFramesFromStream(thumbnailStream);
      final result = await _runModel(frames);
      _setResult(result);
    } finally {
      _setProcessing(false);
    }
  }

  Future<DeepFakeInference> _runModel(List<Uint8List> frames) async {
    if (frames.isEmpty) {
      return DeepFakeInference(label: DeepFakeResultLabel.fake, confidence: 0.0);
    }

    int fakeCount = 0;
    int realCount = 0;
    double totalConfidence = 0.0;

    for (final frame in frames) {
      try {
        final result = await TFLiteService.instance.runInference(frame);
        if (result.label == 'fake') {
          fakeCount++;
        } else {
          realCount++;
        }
        totalConfidence += result.confidence;
      } catch (_) {
        // Skip frame on failure
      }
    }

    final total = fakeCount + realCount;
    if (total == 0) {
      return DeepFakeInference(label: DeepFakeResultLabel.fake, confidence: 0.0);
    }

    final label = fakeCount > realCount ? DeepFakeResultLabel.fake : DeepFakeResultLabel.real;
    final averageConfidence = totalConfidence / total;

    return DeepFakeInference(label: label, confidence: averageConfidence);
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void _setResult(DeepFakeInference result) {
    _lastResult = result;
    notifyListeners();
  }
}
