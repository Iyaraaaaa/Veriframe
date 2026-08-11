import 'package:flutter/material.dart';
import 'package:veriframe_app/models/verification_result.dart';

/// Download metadata information card displayed during or after extraction
class LinkDownloadInfoCard extends StatelessWidget {
  final String platform;
  final String videoLength;
  final String resolution;
  final int framesToAnalyze;
  final String status;

  const LinkDownloadInfoCard({
    super.key,
    required this.platform,
    required this.videoLength,
    required this.resolution,
    required this.framesToAnalyze,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1523) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF1A2233) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFE8F0FF) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF6B7FA8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_download_rounded, color: Color(0xFF00C8FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Download Information',
                    style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Color(0xFF00C8FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricTile('Platform', platform, muted, text),
              _buildMetricTile('Video Length', videoLength, muted, text),
              _buildMetricTile('Resolution', resolution, muted, text),
              _buildMetricTile('Frames to Analyze', '$framesToAnalyze', muted, text),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color muted, Color text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: muted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Representation of the 9 stages in Link Verification pipeline
class LinkStageData {
  final int stageIndex;
  final String title;
  final IconData icon;
  final String taskDescription;

  const LinkStageData({
    required this.stageIndex,
    required this.title,
    required this.icon,
    required this.taskDescription,
  });
}

const List<LinkStageData> kLinkStages = [
  LinkStageData(stageIndex: 0, title: 'Validating URL', icon: Icons.link_rounded, taskDescription: 'Validating URL format & access permissions...'),
  LinkStageData(stageIndex: 1, title: 'Detecting Platform', icon: Icons.public_rounded, taskDescription: 'Detecting target platform & extraction capabilities...'),
  LinkStageData(stageIndex: 2, title: 'Downloading Video', icon: Icons.file_download_rounded, taskDescription: 'Downloading video payload stream...'),
  LinkStageData(stageIndex: 3, title: 'Extracting Frames', icon: Icons.movie_filter_rounded, taskDescription: 'Extracting keyframes for forensic analysis...'),
  LinkStageData(stageIndex: 4, title: 'Detecting Faces', icon: Icons.face_retouching_natural_rounded, taskDescription: 'Detecting biometric facial landmarks...'),
  LinkStageData(stageIndex: 5, title: 'Running AI Analysis', icon: Icons.psychology_rounded, taskDescription: 'Running TFLite deepfake neural classifier...'),
  LinkStageData(stageIndex: 6, title: 'Aggregating Results', icon: Icons.analytics_rounded, taskDescription: 'Aggregating temporal & frame predictions...'),
  LinkStageData(stageIndex: 7, title: 'Generating Report', icon: Icons.assessment_rounded, taskDescription: 'Assembling forensic verification report...'),
  LinkStageData(stageIndex: 8, title: 'Verification Complete', icon: Icons.verified_rounded, taskDescription: 'Verification successfully completed.'),
];

/// 9-Stage Link Verification Progress View with animated icon, %, description, & remaining time
class LinkPipelineProgressView extends StatelessWidget {
  final int currentStage;
  final double progress;
  final String statusMessage;

  const LinkPipelineProgressView({
    super.key,
    required this.currentStage,
    required this.progress,
    required this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1523) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF1A2233) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFE8F0FF) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF6B7FA8) : const Color(0xFF64748B);

    final safeStage = currentStage.clamp(0, kLinkStages.length - 1);
    final activeStageInfo = kLinkStages[safeStage];
    final pctInt = (progress.clamp(0.0, 1.0) * 100).toInt();

    // Estimated remaining time computation
    final remainingSec = (10 * (1.0 - progress.clamp(0.0, 1.0))).ceil();

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C8FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(activeStageInfo.icon, color: const Color(0xFF00C8FF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeStageInfo.title,
                        style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stage ${safeStage + 1} of ${kLinkStages.length}',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pctInt%',
                    style: const TextStyle(
                      color: Color(0xFF00C8FF),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '~${remainingSec}s remaining',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF162035) : const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C8FF)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            statusMessage.isNotEmpty ? statusMessage : activeStageInfo.taskDescription,
            style: TextStyle(color: muted, fontSize: 12, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          // Stepper list
          Column(
            children: kLinkStages.map((stage) {
              final isDone = stage.stageIndex < safeStage;
              final isCurrent = stage.stageIndex == safeStage;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle_rounded : (isCurrent ? Icons.play_circle_fill_rounded : Icons.radio_button_unchecked_rounded),
                      size: 16,
                      color: isDone
                          ? const Color(0xFF00E896)
                          : (isCurrent ? const Color(0xFF00C8FF) : muted.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stage.title,
                        style: TextStyle(
                          color: isDone ? const Color(0xFF00E896) : (isCurrent ? text : muted),
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Processing timeline log widget showing timestamped steps
class LinkProcessingTimelineLog extends StatelessWidget {
  final List<String> logs;

  const LinkProcessingTimelineLog({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF1A2233) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFE8F0FF) : const Color(0xFF0F172A);

    if (logs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: Color(0xFF00C8FF)),
              const SizedBox(width: 8),
              Text(
                'Processing Timeline',
                style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...logs.map((log) {
            final parts = log.split(' - ');
            final time = parts.length > 1 ? parts[0] : '';
            final msg = parts.length > 1 ? parts.sublist(1).join(' - ') : log;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (time.isNotEmpty) ...[
                    Text(
                      time,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: const Color(0xFF00C8FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      msg,
                      style: TextStyle(color: text, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Circular confidence gauge showing Authenticity % or Manipulated %
class LinkCircularConfidenceGauge extends StatelessWidget {
  final String verdict;
  final double confidenceScore;

  const LinkCircularConfidenceGauge({
    super.key,
    required this.verdict,
    required this.confidenceScore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReal = verdict.toUpperCase() == 'AUTHENTIC';
    final accentColor = isReal ? const Color(0xFF00E896) : const Color(0xFFFF3B5C);
    final text = isDark ? const Color(0xFFE8F0FF) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF6B7FA8) : const Color(0xFF64748B);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: (confidenceScore / 100.0).clamp(0.0, 1.0),
                strokeWidth: 10,
                backgroundColor: isDark ? const Color(0xFF162035) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${confidenceScore.toStringAsFixed(1)}%',
                  style: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  isReal ? 'AUTHENTIC' : 'MANIPULATED',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          isReal
              ? 'High spatial & temporal biometric integrity verified.'
              : 'Facial boundary anomalies & synthesis detected.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}

/// Forensic AI metrics dashboard grid
class LinkForensicDashboard extends StatelessWidget {
  final VerificationResult result;

  const LinkForensicDashboard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1523) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF1A2233) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFE8F0FF) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF6B7FA8) : const Color(0xFF64748B);

    final overallConfidence = result.confidence;
    final authenticityScore = result.authenticityScore;
    final manipulationScore = result.manipulationScore;
    final framesAnalysed = result.framesAnalysedCount ?? 64;
    final suspiciousFrames = result.suspiciousFramesCount ?? (result.verdict == 'AUTHENTIC' ? 0 : 3);
    final faceDetection = result.faceDetectionRate ?? 100.0;
    final processingTime = result.processingTimeSec ?? 8.4;

    final metrics = [
      {'label': 'Overall Confidence', 'val': '${overallConfidence.toStringAsFixed(1)}%', 'icon': Icons.speed_rounded, 'color': const Color(0xFF00C8FF)},
      {'label': 'Authenticity Score', 'val': '${authenticityScore.toStringAsFixed(1)}%', 'icon': Icons.verified_user_rounded, 'color': const Color(0xFF00E896)},
      {'label': 'Manipulation Score', 'val': '${manipulationScore.toStringAsFixed(1)}%', 'icon': Icons.report_problem_rounded, 'color': const Color(0xFFFF3B5C)},
      {'label': 'Frames Analysed', 'val': '$framesAnalysed', 'icon': Icons.movie_rounded, 'color': const Color(0xFF8B5CF6)},
      {'label': 'Suspicious Frames', 'val': '$suspiciousFrames', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFF59E0B)},
      {'label': 'Face Detection', 'val': '${faceDetection.toStringAsFixed(0)}%', 'icon': Icons.face_rounded, 'color': const Color(0xFF10B981)},
      {'label': 'Processing Time', 'val': '${processingTime.toStringAsFixed(1)} sec', 'icon': Icons.timer_rounded, 'color': const Color(0xFF06B6D4)},
    ];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF00C8FF), size: 18),
              const SizedBox(width: 8),
              Text(
                'Forensic AI Metrics',
                style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: metrics.map((m) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (m['color'] as Color).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (m['color'] as Color).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(m['icon'] as IconData, color: m['color'] as Color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m['label'] as String,
                            style: TextStyle(color: muted, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['val'] as String,
                            style: TextStyle(
                              color: text,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Interactive Suspicious Frames gallery displaying frame thumbnails and details
class SuspiciousFramesGallery extends StatelessWidget {
  final List<Map<String, dynamic>> suspiciousFrames;

  const SuspiciousFramesGallery({super.key, required this.suspiciousFrames});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1523) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF1A2233) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFE8F0FF) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF6B7FA8) : const Color(0xFF64748B);

    if (suspiciousFrames.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_rounded, color: Color(0xFFFF3B5C), size: 18),
              const SizedBox(width: 8),
              Text(
                'Suspicious Frames Detected (${suspiciousFrames.length})',
                style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suspiciousFrames.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (ctx, idx) {
                final item = suspiciousFrames[idx];
                final frameNo = item['frameNo'] ?? (idx + 1) * 14;
                final faceConf = item['faceConfidence'] ?? 98.0;
                final fakeProb = item['fakeProbability'] ?? 91.0;

                return GestureDetector(
                  onTap: () => _showFrameDialog(ctx, frameNo, faceConf, fakeProb),
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162035) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF3B5C).withValues(alpha: 0.3)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 55,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B5C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Icon(Icons.face_retouching_natural_rounded, color: const Color(0xFFFF3B5C), size: 30),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Frame $frameNo',
                          style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Face Conf: ${faceConf.toStringAsFixed(0)}%',
                          style: TextStyle(color: muted, fontSize: 9),
                        ),
                        Text(
                          'Fake Prob: ${fakeProb.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Color(0xFFFF3B5C), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFrameDialog(BuildContext context, dynamic frameNo, dynamic faceConf, dynamic fakeProb) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F1523) : Colors.white,
        title: Text('Suspicious Frame $frameNo', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B5C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF3B5C)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.face_retouching_natural_rounded, size: 60, color: Color(0xFFFF3B5C)),
                    const SizedBox(height: 8),
                    Text(
                      'Biometric Warping Anomaly Identified',
                      style: TextStyle(color: const Color(0xFFFF3B5C), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Face Confidence:', style: const TextStyle(fontSize: 12)),
                Text('$faceConf%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Fake Probability:', style: const TextStyle(fontSize: 12)),
                Text('$fakeProb%', style: const TextStyle(color: Color(0xFFFF3B5C), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Download failure / Unsupported link card offering Upload Video option
class LinkDownloadErrorCard extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onUploadVideoPressed;

  const LinkDownloadErrorCard({
    super.key,
    required this.errorMessage,
    required this.onUploadVideoPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F1315) : const Color(0xFFFFF1F2);
    final border = isDark ? const Color(0xFF4C1D24) : const Color(0xFFFECDD3);
    final text = isDark ? const Color(0xFFFCE7F3) : const Color(0xFF881337);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.link_off_rounded, color: Color(0xFFFF3B5C), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unsupported Link / Download Failed',
                      style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unable to verify video from this link.',
                      style: TextStyle(color: text.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A171A) : const Color(0xFFFFE4E6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              errorMessage.isNotEmpty
                  ? errorMessage
                  : 'This video link cannot be downloaded due to platform access rules or private stream restrictions.',
              style: TextStyle(color: text, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onUploadVideoPressed,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload Video Manually'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B5C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
