import 'package:flutter/material.dart';
import 'package:veriframe_app/models/verification_result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS & CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

class LinkVerificationStage {
  final int stageIndex;
  final String title;
  final String taskDescription;
  final IconData icon;

  const LinkVerificationStage({
    required this.stageIndex,
    required this.title,
    required this.taskDescription,
    required this.icon,
  });
}

const List<LinkVerificationStage> kLinkStages = [
  LinkVerificationStage(
    stageIndex: 0,
    title: 'Validating URL',
    taskDescription: 'Checking URL syntax, cryptographic schema, and domain reputation',
    icon: Icons.link_rounded,
  ),
  LinkVerificationStage(
    stageIndex: 1,
    title: 'Detecting Platform',
    taskDescription: 'Identifying video host, CDN endpoint, and extractor profile',
    icon: Icons.public_rounded,
  ),
  LinkVerificationStage(
    stageIndex: 2,
    title: 'Downloading Stream',
    taskDescription: 'Retrieving media payload into secure forensic sandbox',
    icon: Icons.cloud_download_rounded,
  ),
  LinkVerificationStage(
    stageIndex: 3,
    title: 'Sampling Keyframes',
    taskDescription: 'Decoding video container and extracting scene-aware keyframes',
    icon: Icons.movie_filter_rounded,
  ),
  LinkVerificationStage(
    stageIndex: 4,
    title: 'Biometric Detection',
    taskDescription: 'Locating facial boundaries, landmarks, and spatial tracking vectors',
    icon: Icons.face_retouching_natural_rounded,
  ),
  LinkVerificationStage(
    stageIndex: 5,
    title: 'Neural Deepfake Inference',
    taskDescription: 'Evaluating keyframe crops with on-device & cloud forensic classifiers',
    icon: Icons.psychology_rounded,
  ),
  LinkVerificationStage(
    stageIndex: 6,
    title: 'Forensic Aggregation',
    taskDescription: 'Fusing spatial, temporal, frequency, and sensor noise evidence',
    icon: Icons.analytics_rounded,
  ),
  LinkVerificationStage(
    stageIndex: 7,
    title: 'Verification Complete',
    taskDescription: 'Compiling cryptographic forensic report and audit trail',
    icon: Icons.verified_rounded,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// 1. PROGRESS / RUNNING CARD
// ─────────────────────────────────────────────────────────────────────────────

class LinkVerificationProgressCard extends StatelessWidget {
  final double progress;
  final int currentStage;
  final String statusMessage;

  const LinkVerificationProgressCard({
    super.key,
    required this.progress,
    required this.currentStage,
    required this.statusMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final safeStage = currentStage.clamp(0, kLinkStages.length - 1);
    final activeStageInfo = kLinkStages[safeStage];
    final pctInt = (progress * 100).toInt().clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(activeStageInfo.icon, color: const Color(0xFF0284C7), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STAGE ${safeStage + 1} OF ${kLinkStages.length}',
                      style: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeStageInfo.title,
                      style: TextStyle(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$pctInt%',
                style: const TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            statusMessage.isNotEmpty ? statusMessage : activeStageInfo.taskDescription,
            style: TextStyle(color: muted, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Column(
            children: kLinkStages.map((stage) {
              final isDone = stage.stageIndex < safeStage;
              final isCurrent = stage.stageIndex == safeStage;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : (isCurrent ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                      size: 16,
                      color: isDone
                          ? const Color(0xFF10B981)
                          : (isCurrent ? const Color(0xFF0284C7) : muted.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        stage.title,
                        style: TextStyle(
                          color: isDone ? const Color(0xFF10B981) : (isCurrent ? text : muted),
                          fontSize: 12.5,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
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

// ─────────────────────────────────────────────────────────────────────────────
// 2. VIDEO METADATA & PLATFORM HEADER
// ─────────────────────────────────────────────────────────────────────────────

class LinkVideoHeaderCard extends StatelessWidget {
  final VerificationResult result;

  const LinkVideoHeaderCard({super.key, required this.result});

  Color _getPlatformColor(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('youtube')) return const Color(0xFFFF0000);
    if (lower.contains('instagram')) return const Color(0xFFE1306C);
    if (lower.contains('facebook')) return const Color(0xFF1877F2);
    if (lower.contains('tiktok')) return const Color(0xFF00F2FE);
    if (lower.contains('twitter') || lower.contains('x')) return const Color(0xFF1DA1F2);
    return const Color(0xFF0284C7);
  }

  IconData _getPlatformIcon(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('youtube')) return Icons.play_circle_fill_rounded;
    if (lower.contains('instagram')) return Icons.camera_alt_rounded;
    if (lower.contains('facebook')) return Icons.facebook_rounded;
    if (lower.contains('tiktok')) return Icons.music_note_rounded;
    return Icons.public_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final platformName = result.platform ?? 'Web Video';
    final platformColor = _getPlatformColor(platformName);
    final rawUrl = result.videoUrl ?? result.mediaPath ?? '';
    final domain = Uri.tryParse(rawUrl)?.host.toLowerCase().replaceAll('www.', '') ?? platformName;
    final res = result.resolution ?? 'Standard';
    final length = result.videoLength ?? '0:15';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: platformColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: platformColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getPlatformIcon(platformName), size: 14, color: platformColor),
                    const SizedBox(width: 6),
                    Text(
                      platformName.toUpperCase(),
                      style: TextStyle(
                        color: platformColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  domain,
                  style: TextStyle(color: muted, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rawUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetaChip(Icons.aspect_ratio_rounded, res, isDark),
              const SizedBox(width: 8),
              _buildMetaChip(Icons.timer_outlined, length, isDark),
              const SizedBox(width: 8),
              _buildMetaChip(
                Icons.analytics_outlined,
                '${result.framesAnalysedCount ?? 0} frames',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF0284C7)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. HERO VERDICT & CONFIDENCE BANNER
// ─────────────────────────────────────────────────────────────────────────────

class LinkVerdictHeroCard extends StatelessWidget {
  final VerificationResult result;

  const LinkVerdictHeroCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vUpper = result.verdict.toUpperCase();

    final bool isAuthentic = vUpper == 'AUTHENTIC';
    final bool isManipulated = vUpper == 'MANIPULATED' || vUpper == 'FAKE';
    final bool isInconclusive = vUpper == 'INCONCLUSIVE';
    final bool isUnverified = vUpper == 'UNVERIFIED';

    final Color brandColor = isAuthentic
        ? const Color(0xFF10B981)
        : (isManipulated
            ? const Color(0xFFEF4444)
            : (isInconclusive ? const Color(0xFFF59E0B) : const Color(0xFF64748B)));

    final String verdictTitle = isAuthentic
        ? 'VERIFIED AUTHENTIC'
        : (isManipulated
            ? 'SYNTHETIC / MANIPULATED'
            : (isInconclusive ? 'INCONCLUSIVE EVIDENCE' : 'UNVERIFIED LINK'));

    final String subtitleText = isAuthentic
        ? 'Natural optical camera sensor noise and consistent temporal facial motion verified across all sampled keyframes.'
        : (isManipulated
            ? 'Generative synthetic artifacts and inter-frame facial texture warping detected across video timeline.'
            : (isInconclusive
                ? 'Borderline biometric indicators or compressed resolution. Deepfake probability lies in the neutral range.'
                : 'Video payload could not be extracted directly. Please upload the raw video file for analysis.'));

    final double displayScore = isAuthentic
        ? result.authenticityScore
        : (isManipulated ? result.fakeProbability : (result.confidence > 0 ? result.confidence : 50.0));

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: brandColor.withValues(alpha: 0.35), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: brandColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAuthentic
                      ? Icons.verified_user_rounded
                      : (isManipulated ? Icons.gpp_bad_rounded : Icons.help_outline_rounded),
                  color: brandColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  verdictTitle,
                  style: TextStyle(
                    color: brandColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                isUnverified ? 'N/A' : displayScore.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -1.5,
                ),
              ),
              if (!isUnverified) ...[
                const SizedBox(width: 4),
                Text(
                  '%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: brandColor,
                  ),
                ),
              ],
            ],
          ),
          Text(
            isAuthentic
                ? 'AUTHENTICITY INDEX'
                : (isManipulated ? 'DEEPFAKE RISK INDEX' : 'CONFIDENCE SCORE'),
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          // Dual-side progress bar
          if (!isUnverified) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: result.authenticityScore.toInt().clamp(1, 99),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                    Expanded(
                      flex: result.fakeProbability.toInt().clamp(1, 99),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Authentic: ${result.authenticityScore.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Manipulation: ${result.fakeProbability.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Text(
            subtitleText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. FORENSIC AI METRICS DASHBOARD GRID
// ─────────────────────────────────────────────────────────────────────────────

class LinkForensicDashboard extends StatelessWidget {
  final VerificationResult result;

  const LinkForensicDashboard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final isUnverified = result.verdict.toUpperCase() == 'UNVERIFIED';

    final faceDetection = result.faceDetectionRate ?? (result.trackingConfidence > 0 ? result.trackingConfidence : 0.0);
    final framesCount = result.framesAnalysedCount ?? 0;
    final procTime = result.processingTimeSec ?? 1.4;

    final metrics = [
      {
        'label': 'Overall Confidence',
        'val': isUnverified ? 'N/A' : '${result.confidence.toStringAsFixed(1)}%',
        'icon': Icons.speed_rounded,
        'color': const Color(0xFF0284C7),
      },
      {
        'label': 'Sampled Frames',
        'val': isUnverified ? '0' : '$framesCount keyframes',
        'icon': Icons.movie_filter_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'label': 'Face Coverage',
        'val': isUnverified ? '0%' : '${faceDetection.toStringAsFixed(0)}%',
        'icon': Icons.face_retouching_natural_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Tracking Stability',
        'val': isUnverified ? 'N/A' : '${result.trackingConfidence.toStringAsFixed(1)}%',
        'icon': Icons.timeline_rounded,
        'color': const Color(0xFF06B6D4),
      },
      {
        'label': 'Frame Consistency',
        'val': isUnverified ? 'N/A' : '${result.frameConsistency.toStringAsFixed(1)}%',
        'icon': Icons.auto_awesome_motion_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Analysis Latency',
        'val': '${procTime.toStringAsFixed(1)}s',
        'icon': Icons.timer_rounded,
        'color': const Color(0xFFEC4899),
      },
    ];

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF0284C7), size: 18),
              const SizedBox(width: 8),
              Text(
                'Forensic AI Diagnostics',
                style: TextStyle(color: text, fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: metrics.map((m) {
              final color = m['color'] as Color;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(m['icon'] as IconData, color: color, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m['label'] as String,
                            style: TextStyle(color: muted, fontSize: 10.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m['val'] as String,
                            style: TextStyle(
                              color: text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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

// ─────────────────────────────────────────────────────────────────────────────
// 5. SUSPICIOUS FRAMES VIEW (DYNAMIC OR CLEAN AUDIT)
// ─────────────────────────────────────────────────────────────────────────────

class SuspiciousFramesGallery extends StatelessWidget {
  final List<Map<String, dynamic>> suspiciousFrames;

  const SuspiciousFramesGallery({super.key, required this.suspiciousFrames});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (suspiciousFrames.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Manipulated Keyframes Detected',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All sampled keyframes passed temporal consistency and facial boundary checks.',
                    style: TextStyle(color: muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 8),
              Text(
                'Suspicious Keyframes Detected (${suspiciousFrames.length})',
                style: TextStyle(color: text, fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suspiciousFrames.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final item = suspiciousFrames[idx];
                final frameNo = item['frameNo'] ?? (idx + 1);
                final faceConf = (item['faceConfidence'] as num?)?.toDouble() ?? 95.0;
                final fakeProb = (item['fakeProbability'] as num?)?.toDouble() ?? 88.0;

                return Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.face_retouching_natural_rounded, color: Color(0xFFEF4444), size: 24),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Frame #$frameNo',
                        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Fake: ${fakeProb.toStringAsFixed(0)}%',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Tracking: ${faceConf.toStringAsFixed(0)}%',
                        style: TextStyle(color: muted, fontSize: 9.5),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. PROCESSING TIMELINE AUDIT LOG
// ─────────────────────────────────────────────────────────────────────────────

class LinkProcessingTimelineLog extends StatelessWidget {
  final List<String> logs;

  const LinkProcessingTimelineLog({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final text = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);


    if (logs.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu_rounded, size: 18, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Text(
                'Forensic Audit Timeline',
                style: TextStyle(color: text, fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...logs.map((log) {
            final parts = log.split(' - ');
            final time = parts.length > 1 ? parts[0] : '';
            final msg = parts.length > 1 ? parts.sublist(1).join(' - ') : log;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (time.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        time,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFF0284C7),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      msg,
                      style: TextStyle(color: text, fontSize: 12, height: 1.3),
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

// ─────────────────────────────────────────────────────────────────────────────
// 7. DOWNLOAD / UNREACHABLE ERROR CARD
// ─────────────────────────────────────────────────────────────────────────────

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
    final bg = isDark ? const Color(0xFF1E1014) : const Color(0xFFFFF1F2);
    final border = isDark ? const Color(0xFF4C1D24) : const Color(0xFFFECDD3);
    final text = isDark ? const Color(0xFFFCE7F3) : const Color(0xFF881337);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video Stream Retrieval Failed',
                      style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Platform access restricted or stream protected.',
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              errorMessage.isNotEmpty
                  ? errorMessage.replaceAll('Exception: ', '').trim()
                  : 'The media link could not be downloaded due to platform bot protection or private stream rules. Direct file upload is recommended.',
              style: TextStyle(color: text, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onUploadVideoPressed,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload Video File Directly'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
