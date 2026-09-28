// lib/service/tflite_service.dart
import 'dart:typed_data';

import 'tflite_service_stub.dart'
    if (dart.library.io) 'tflite_service_mobile.dart'
    if (dart.library.html) 'tflite_service_web.dart' as impl;

class InferenceResult {
  final String label;
  final double confidence;
  final List<double> rawOutput;
  final int inferenceMs;
  final bool reverseLabels;

  const InferenceResult({
    required this.label,
    required this.confidence,
    required this.rawOutput,
    required this.inferenceMs,
    this.reverseLabels = false,
  });

  double get fakeProbability {
    if (rawOutput.isNotEmpty) {
      final score = rawOutput.first;
      return reverseLabels ? (1.0 - score) : score;
    }
    return label.toLowerCase() == 'fake' ? confidence : 1.0 - confidence;
  }
}

abstract class TFLiteService {
  static TFLiteService get instance => impl.getTFLiteServiceInstance();

  bool get isInitialized;
  Future<void> init();
  Future<InferenceResult> runInference(Uint8List imageBytes);
  void close();
}
