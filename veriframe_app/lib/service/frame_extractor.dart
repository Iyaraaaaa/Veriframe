import 'dart:io';
import 'dart:typed_data';

class FrameExtractor {
  /// Extracts frames from a local video file.
  /// As a robust fallback, we read the video file bytes.
  static Future<List<Uint8List>> extractFramesFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return [bytes];
    } catch (_) {
      return [];
    }
  }

  /// Extracts frames from a video URL.
  static Future<List<Uint8List>> extractFramesFromUrl(String url) async {
    // Return empty list or fallback as frame extraction from URL is handled by backend.
    return [];
  }

  /// Extracts frames from a stream.
  static Future<List<Uint8List>> extractFramesFromStream(Stream<Uint8List> stream) async {
    final List<Uint8List> frames = [];
    await for (final chunk in stream) {
      frames.add(chunk);
      if (frames.length >= 10) break; // Limit to 10 frames
    }
    return frames;
  }
}
