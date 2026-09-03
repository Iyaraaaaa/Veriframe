// lib/service/tflite_service_mobile.dart
import 'dart:developer' as dev;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tflite_service.dart';

TFLiteService getTFLiteServiceInstance() => TFLiteServiceMobile.instance;

class TFLiteServiceMobile implements TFLiteService {
  TFLiteServiceMobile._();
  static final TFLiteServiceMobile instance = TFLiteServiceMobile._();

  Interpreter? _interpreter;
  List<String> _labels = ['real', 'fake'];
  List<int> _inputShape = [1, 224, 224, 3];
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset('assets/veriframe_model.tflite');
      _inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      dev.log('[TFLite] Model loaded successfully', name: 'TFLiteService');
      dev.log('[TFLite] Input  shape : $_inputShape', name: 'TFLiteService');
      dev.log('[TFLite] Output shape : $outputShape', name: 'TFLiteService');

      await _loadLabels();
      _isInitialized = true;
    } catch (e) {
      dev.log('[TFLite] Init ERROR: $e', name: 'TFLiteService', level: 1000);
      rethrow;
    }
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString('assets/labels.txt');
      final parsed = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) _labels = parsed;
      dev.log('[TFLite] Labels: $_labels', name: 'TFLiteService');
    } catch (_) {
      dev.log('[TFLite] labels.txt not found — using defaults: $_labels',
          name: 'TFLiteService');
    }
  }

  @override
  Future<InferenceResult> runInference(Uint8List imageBytes) async {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('TFLiteService not initialised. Call init() first.');
    }

    final height = _inputShape.length >= 3 ? _inputShape[1] : 224;
    final width  = _inputShape.length >= 3 ? _inputShape[2] : 224;

    img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ArgumentError('Unable to decode image bytes.');
    }

    final resized = img.copyResize(decoded, width: width, height: height);

    final inputTensor = List.generate(
      1,
      (_) => List.generate(
        height,
        (y) => List.generate(
          width,
          (x) {
            final pixel = resized.getPixel(x, y);
            // Model expects raw pixel values in 0-255 range and RGB channel order
            return [
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          },
        ),
      ),
    );

    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final isSigmoid = outputShape.length >= 2 && outputShape[1] == 1;
    final outputBuffer = [List<double>.filled(outputShape.length >= 2 ? outputShape[1] : 1, 0.0)];

    final sw = Stopwatch()..start();
    _interpreter!.run(inputTensor, outputBuffer);
    sw.stop();

    dev.log('[TFLite] Raw output   : ${outputBuffer[0]}', name: 'TFLiteService');
    dev.log('[TFLite] Inference time: ${sw.elapsedMilliseconds}ms', name: 'TFLiteService');

    String label;
    double confidence;
    List<double> rawValues;

    if (isSigmoid) {
      final sigmoidScore = outputBuffer[0][0];
      // Model training class order: real=0 (low score), fake=1 (high score)
      if (sigmoidScore >= 0.5) {
        label = "fake";
        confidence = sigmoidScore;
      } else {
        label = "real";
        confidence = 1.0 - sigmoidScore;
      }
      rawValues = [sigmoidScore];
    } else {
      final values = outputBuffer[0];
      int bestIdx = 0;
      double bestScore = values[0];
      for (int i = 1; i < values.length; i++) {
        if (values[i] > bestScore) {
          bestScore = values[i];
          bestIdx = i;
        }
      }
      label = bestIdx < _labels.length ? _labels[bestIdx] : 'unknown';
      confidence = bestScore;
      rawValues = values;
    }

    return InferenceResult(
      label: label,
      confidence: confidence.clamp(0.0, 1.0),
      rawOutput: rawValues,
      inferenceMs: sw.elapsedMilliseconds,
    );
  }

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    dev.log('[TFLite] Interpreter closed.', name: 'TFLiteService');
  }
}
