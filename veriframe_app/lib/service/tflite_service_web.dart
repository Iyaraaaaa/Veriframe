// lib/service/tflite_service_web.dart
import 'dart:typed_data';
import 'tflite_service.dart';

TFLiteService getTFLiteServiceInstance() => TFLiteServiceWeb.instance;

class TFLiteServiceWeb implements TFLiteService {
  TFLiteServiceWeb._();
  static final TFLiteServiceWeb instance = TFLiteServiceWeb._();

  @override
  bool get isInitialized => true;

  @override
  Future<void> init() async {
    // No-op on Web. Web client uses backend inference since native WebAssembly TFLite is not local.
  }

  @override
  Future<InferenceResult> runInference(Uint8List imageBytes) async {
    return const InferenceResult(
      label: 'fake',
      confidence: 0.0,
      rawOutput: [0.0, 0.0],
      inferenceMs: 0,
    );
  }

  @override
  void close() {
    // No-op
  }
}
