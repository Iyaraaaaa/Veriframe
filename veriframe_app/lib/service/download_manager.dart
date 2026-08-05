import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  final Dio _dio = Dio();

  static const Set<String> _socialMediaDomains = {
    'youtube.com',
    'youtu.be',
    'm.youtube.com',
    'googlevideo.com',
    'tiktok.com',
    'vm.tiktok.com',
    'www.tiktok.com',
    'instagram.com',
    'www.instagram.com',
    'cdninstagram.com',
    'facebook.com',
    'www.facebook.com',
    'fb.watch',
    'fbcdn.net',
    'twitter.com',
    'www.twitter.com',
    'x.com',
    'twimg.com',
    'vimeo.com',
    'www.vimeo.com',
    'vimeocdn.com',
    'twitch.tv',
    'www.twitch.tv',
    'dailymotion.com',
  };

  bool requiresServerExtraction(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      return _socialMediaDomains.any(
        (domain) => host == domain || host.endsWith('.$domain'),
      );
    } catch (_) {
      return false;
    }
  }

  bool isDirectVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m3u8') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.contains('mime=video');
  }

  Future<String> download(
    String url, {
    void Function(double)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final pathSegments = Uri.parse(url).pathSegments;
    final fileName = pathSegments.isNotEmpty
        ? pathSegments.last
        : 'video_${DateTime.now().millisecondsSinceEpoch}';
    final filePath = '${tempDir.path}${Platform.pathSeparator}$fileName';

    await _dio.download(
      url,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    return filePath;
  }
}