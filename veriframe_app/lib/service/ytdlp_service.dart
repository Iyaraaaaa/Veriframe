import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class YtDlpService {
  YtDlpService._();
  static final YtDlpService instance = YtDlpService._();

  static const String _ytDlpAssetName = 'yt-dlp';

  Future<String?> _findYtDlpBinary() async {
    if (!Platform.isAndroid) return null;

    final appDir = await getApplicationDocumentsDirectory();
    final binaryPath = '${appDir.path}/$_ytDlpAssetName';
    final file = File(binaryPath);
    if (await file.exists()) return binaryPath;

    final tempDir = await getTemporaryDirectory();
    final tempBinaryPath = '${tempDir.path}/$_ytDlpAssetName';
    final tempFile = File(tempBinaryPath);
    if (await tempFile.exists()) return tempBinaryPath;

    return null;
  }

  Future<String> downloadToTemp(String url) async {
    final binaryPath = await _findYtDlpBinary();

    if (binaryPath != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final outputTemplate =
            '${tempDir.path}/ytdlp_${DateTime.now().millisecondsSinceEpoch}.mp4';

        final result = await Process.run(
          binaryPath,
          [
            '-f', 'best[ext=mp4]',
            '-o', outputTemplate,
            '--no-playlist',
            '--newline',
            url,
          ],
        ).timeout(const Duration(minutes: 5));

        if (result.exitCode == 0) {
          final downloadedFile = File(outputTemplate);
          if (await downloadedFile.exists()) {
            return outputTemplate;
          }
        }
      } catch (_) {}
    }

    return await _fallbackHttpDownload(url);
  }

  Future<String> _fallbackHttpDownload(String url) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        'ytdlp_fallback_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final filePath = '${tempDir.path}/$fileName';

    final dio = Dio();
    await dio.download(
      url,
      filePath,
    );

    return filePath;
  }
}