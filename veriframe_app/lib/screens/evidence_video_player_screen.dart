import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/widgets/escalate_bottom_sheet.dart';

class EvidenceVideoPlayerScreen extends StatefulWidget {
  final VerificationResult report;

  const EvidenceVideoPlayerScreen({super.key, required this.report});

  @override
  State<EvidenceVideoPlayerScreen> createState() =>
      _EvidenceVideoPlayerScreenState();
}

class _EvidenceVideoPlayerScreenState extends State<EvidenceVideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final videoPath = widget.report.mediaPath;
    final videoUrl = widget.report.videoUrl;

    String? sourcePath;
    bool isNetwork = false;

    if (videoUrl != null && videoUrl.trim().isNotEmpty) {
      isNetwork = true;
      sourcePath = videoUrl;
    } else if (videoPath != null &&
        videoPath.isNotEmpty &&
        !videoPath.startsWith('stream-') &&
        !videoPath.startsWith('http')) {
      final file = File(videoPath);
      if (await file.exists()) {
        sourcePath = videoPath;
      } else {
        setState(() {
          _errorMessage =
              'Evidence video file not found at the stored path. It may have been moved or deleted.';
        });
        return;
      }
    } else {
      setState(() {
        _errorMessage =
            'No local video evidence available for this report.';
      });
      return;
    }

    try {
      if (isNetwork) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(sourcePath));
      } else {
        _controller = VideoPlayerController.file(File(sourcePath));
      }
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.setLooping(true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load video: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final r = widget.report;
    final vUpper = r.verdict.toUpperCase();
    final isReal = vUpper == 'AUTHENTIC';
    final isInconclusive = vUpper == 'INCONCLUSIVE';
    final isUnverified = vUpper == 'UNVERIFIED';
    final accentColor = isReal
        ? const Color(0xFF00E896)
        : (isInconclusive
            ? const Color(0xFFF59E0B)
            : (isUnverified ? const Color(0xFF94A3B8) : const Color(0xFFFF3B5C)));

    final hasCloudUrl =
        r.videoUrl != null && r.videoUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.evidenceVideoTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              r.mediaName ?? 'Evidence',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.report_gmailerrorred_rounded, size: 22),
            tooltip: loc.verifyReportMedia,
            onPressed: _reportMedia,
          ),
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorView(accentColor)
          : !_isInitialized
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.movie_creation_outlined,
                          color: accentColor,
                          size: 28,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        loc.evidenceLoadingVideo,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio > 0
                            ? _controller.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  r.source,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  isUnverified
                                      ? '${r.verdict} • N/A'
                                      : '${r.verdict} • ${(isReal ? r.authenticityScore : r.fakeProbability).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (hasCloudUrl)
                              _buildVideoUrlRow(
                                r.videoUrl!,
                                loc,
                                accentColor,
                                isFromStorage: r.videoStoragePath != null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _errorMessage != null
          ? null
          : !_isInitialized
              ? null
              : FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                      _isPlaying
                          ? _controller.play()
                          : _controller.pause();
                    });
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  highlightElevation: 0,
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: accentColor,
                    size: 42,
                  ),
                ),
    );
  }

  Widget _buildErrorView(Color accentColor) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: accentColor,
              size: 42,
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back),
              label: Text(loc.evidenceBackToReport),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoUrlRow(
    String url,
    AppLocalizations loc,
    Color accentColor, {
    bool isFromStorage = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.evidenceVideoSource,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 9.5,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  url,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _copyUrl(url, loc),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                ),
              ),
              if (isFromStorage) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(url.trim());
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _copyUrl(String url, AppLocalizations loc) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.evidenceUrlCopied),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _reportMedia() async {
    final pdfPath = widget.report.pdfPath;
    final pdfUrl = widget.report.pdfUrl;
    if ((pdfPath == null || pdfPath.isEmpty) &&
        (pdfUrl == null || pdfUrl.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Forensic report not found. Please verify the media again.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    if (pdfPath != null &&
        pdfPath.isNotEmpty &&
        File(pdfPath).existsSync()) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EscalateBottomSheet(report: widget.report),
      );
      return;
    }
    if (pdfUrl != null && pdfUrl.trim().isNotEmpty) {
      final uri = Uri.parse(pdfUrl.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Forensic report not found. Please verify the media again.',
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
