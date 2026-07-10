import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Custom exception types for descriptive error handling
class VerifyException implements Exception {
  final String message;
  VerifyException(this.message);
  @override
  String toString() => message;
}

class BackendOfflineException extends VerifyException {
  BackendOfflineException(super.message);
}

class ConnectionTimeoutException extends VerifyException {
  ConnectionTimeoutException(super.message);
}

class ServerException extends VerifyException {
  ServerException(super.message);
}

class InvalidResponseException extends VerifyException {
  InvalidResponseException(super.message);
}

/// Helper request class that tracks upload bytes for progress reporting
class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(double progress)? onProgress;

  MultipartRequestWithProgress(
    super.method,
    super.url, {
    this.onProgress,
  });

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final totalLength = contentLength;
    int bytesUploaded = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesUploaded += data.length;
        if (totalLength > 0) {
          onProgress!(bytesUploaded / totalLength);
        }
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}

class VerifyBackendService {
  VerifyBackendService._();
  static final VerifyBackendService instance = VerifyBackendService._();

  static const String _kBackendKey = 'backend_base_url';
  final http.Client _client = http.Client();

  /// Retrieve the base URL, with auto-detection for Android Emulator
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kBackendKey);
    if (saved != null && saved.isNotEmpty) {
      return saved.replaceAll(RegExp(r'/$'), '');
    }

    if (Platform.isAndroid) {
      // Auto-detect standard loopback configuration for emulators
      const emulatorUrl = 'http://10.0.2.2:8000';
      if (await isBackendAvailable(emulatorUrl)) {
        await prefs.setString(_kBackendKey, emulatorUrl);
        return emulatorUrl;
      }
    }

    return '';
  }

  /// Save base URL configured by user
  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    await prefs.setString(_kBackendKey, cleanUrl);
  }

  /// Simple ping check to see if the server is alive
  Future<bool> isBackendAvailable(String baseUrl) async {
    if (baseUrl.isEmpty) return false;
    try {
      final uri = Uri.parse(baseUrl);
      final response = await _client.get(uri).timeout(const Duration(seconds: 2));
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  /// Sends a local video to POST /predict, with upload progress tracking
  Future<Map<String, dynamic>> predictVideo(
    String baseUrl,
    File file, {
    void Function(double)? onUploadProgress,
  }) async {
    final uri = Uri.parse('$baseUrl/predict');
    
    try {
      final request = MultipartRequestWithProgress(
        'POST',
        uri,
        onProgress: onUploadProgress,
      );

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException('Upload timed out.'),
      );

      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw ServerException(_parseErrorDetail(response.body, response.statusCode));
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        throw InvalidResponseException('Invalid response structure received.');
      }

      if (data.containsKey('error')) {
        throw VerifyException(data['error'].toString());
      }

      return Map<String, dynamic>.from(data);
    } on SocketException catch (_) {
      throw BackendOfflineException('Backend server is unreachable.');
    } on TimeoutException catch (_) {
      throw ConnectionTimeoutException('Request timed out. Please check network connection.');
    } on FormatException catch (_) {
      throw InvalidResponseException('Failed to parse backend response JSON.');
    }
  }

  /// POST /verify/link - returns job ID
  Future<String> verifyLink(String baseUrl, String url) async {
    final uri = Uri.parse('$baseUrl/verify/link');
    
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw ServerException(_parseErrorDetail(response.body, response.statusCode));
      }

      final data = jsonDecode(response.body);
      final jobId = data['job_id'];
      if (jobId == null || jobId.toString().isEmpty) {
        throw InvalidResponseException('Backend did not return a valid Job ID.');
      }

      return jobId.toString();
    } on SocketException catch (_) {
      throw BackendOfflineException('Backend server is unreachable.');
    } on TimeoutException catch (_) {
      throw ConnectionTimeoutException('Verification request timed out.');
    }
  }

  /// POST /verify/stream - returns session ID
  Future<String> verifyStream(String baseUrl, String streamUrl) async {
    final uri = Uri.parse('$baseUrl/verify/stream');
    
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'stream_url': streamUrl}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw ServerException(_parseErrorDetail(response.body, response.statusCode));
      }

      final data = jsonDecode(response.body);
      final sessionId = data['session_id'];
      if (sessionId == null || sessionId.toString().isEmpty) {
        throw InvalidResponseException('Backend did not return a valid Session ID.');
      }

      return sessionId.toString();
    } on SocketException catch (_) {
      throw BackendOfflineException('Backend server is unreachable.');
    } on TimeoutException catch (_) {
      throw ConnectionTimeoutException('Stream request timed out.');
    }
  }

  /// POST /analyze/stream/frame - analyzes a base64 encoded frame
  Future<Map<String, dynamic>> analyzeStreamFrame(
    String baseUrl,
    String frameBase64,
    String sessionId,
  ) async {
    final uri = Uri.parse('$baseUrl/analyze/stream/frame');
    
    try {
      final response = await _client.post(
        uri,
        body: {
          'frame_base64': frameBase64,
          'session_id': sessionId,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw ServerException(_parseErrorDetail(response.body, response.statusCode));
      }

      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data);
    } on SocketException catch (_) {
      throw BackendOfflineException('Backend server is offline.');
    } on TimeoutException catch (_) {
      throw ConnectionTimeoutException('Frame analysis timed out.');
    }
  }

  /// GET /analysis/{id} - polls job status
  Future<Map<String, dynamic>> getAnalysis(String baseUrl, String id) async {
    final uri = Uri.parse('$baseUrl/analysis/$id');
    
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw ServerException(_parseErrorDetail(response.body, response.statusCode));
      }

      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data);
    } on SocketException catch (_) {
      throw BackendOfflineException('Backend server offline.');
    } on TimeoutException catch (_) {
      throw ConnectionTimeoutException('Status poll timed out.');
    }
  }

  /// POST /report/create - creates forensic report
  Future<Map<String, dynamic>> createReport(
    String baseUrl, {
    String sessionId = '',
    String jobId = '',
  }) async {
    final uri = Uri.parse('$baseUrl/report/create');
    
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'job_id': jobId,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        throw ServerException(_parseErrorDetail(response.body, response.statusCode));
      }

      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data);
    } on SocketException catch (_) {
      throw BackendOfflineException('Backend is unreachable.');
    } on TimeoutException catch (_) {
      throw ConnectionTimeoutException('Report generation timed out.');
    }
  }

  /// POST /report/send - escalates report to authorities
  Future<String> sendReport(String baseUrl, String reportId, String target) async {
    final uri = Uri.parse('$baseUrl/report/send');
    
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'report_id': reportId,
          'target': target,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw ServerException(_parseErrorDetail(response.body, response.statusCode));
      }

      final data = jsonDecode(response.body);
      return data['message'] ?? 'Report escalated successfully.';
    } on SocketException catch (_) {
      throw BackendOfflineException('Backend server is offline.');
    } on TimeoutException catch (_) {
      throw ConnectionTimeoutException('Escalation request timed out.');
    }
  }

  /// Parses detail error from server responses
  String _parseErrorDetail(String responseBody, int statusCode) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
    } catch (_) {}
    return 'Server error (Status $statusCode)';
  }
}
