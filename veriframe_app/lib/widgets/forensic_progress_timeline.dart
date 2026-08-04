import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

List<String> getForensicStages(BuildContext context) {
  final loc = AppLocalizations.of(context)!;
  return [
    loc.stagePreparingAnalysis,
    loc.stageValidatingMedia,
    loc.stageDownloading,
    loc.stageExtractingMetadata,
    loc.stageSelectingFrames,
    loc.stageDetectingFaces,
    loc.stageTrackingFaces,
    loc.stageAssessingQuality,
    loc.stageRunningAiAnalysis,
    loc.stageVerifyingTemporalConsistency,
    loc.stageAggregatingEvidence,
    loc.stageCalibratingConfidence,
    loc.stageGeneratingReport,
    loc.stageVerificationComplete,
  ];
}

const List<String> kForensicStagesKeys = [
  'stagePreparingAnalysis',
  'stageValidatingMedia',
  'stageDownloading',
  'stageExtractingMetadata',
  'stageSelectingFrames',
  'stageDetectingFaces',
  'stageTrackingFaces',
  'stageAssessingQuality',
  'stageRunningAiAnalysis',
  'stageVerifyingTemporalConsistency',
  'stageAggregatingEvidence',
  'stageCalibratingConfidence',
  'stageGeneratingReport',
  'stageVerificationComplete',
];

class ForensicProgressTimeline extends StatefulWidget {
  final int currentStageIndex;
  final String stageStatusMessage;
  final Map<String, dynamic>? stageMetrics;

  const ForensicProgressTimeline({
    super.key,
    required this.currentStageIndex,
    this.stageStatusMessage = '',
    this.stageMetrics,
  });

  @override
  State<ForensicProgressTimeline> createState() => _ForensicProgressTimelineState();
}

class _ForensicProgressTimelineState extends State<ForensicProgressTimeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final stages = getForensicStages(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2740)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.timelineTitle,
                style: const TextStyle(
                  color: Color(0xFF00C8FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                loc.timelineStage(widget.currentStageIndex + 1, stages.length),
                style: const TextStyle(
                  color: Color(0xFF6B7FA8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stages.length,
            itemBuilder: (context, index) {
              final isCompleted = index < widget.currentStageIndex;
              final isActive = index == widget.currentStageIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step indicator circle/icon
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          if (isCompleted)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E896),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.black,
                              ),
                            )
                          else if (isActive)
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (context, child) {
                                return Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C8FF)
                                        .withOpacity(_pulseAnim.value),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00C8FF)
                                            .withOpacity(0.5 * _pulseAnim.value),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1C2740),
                                  width: 2,
                                ),
                              ),
                            ),
                          if (index < stages.length - 1)
                            Container(
                              width: 2,
                              height: isActive ? 24 : 16,
                              color: isCompleted
                                  ? const Color(0xFF00E896).withOpacity(0.5)
                                  : const Color(0xFF1C2740),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Stage title & subtitle details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stages[index],
                            style: TextStyle(
                              color: isCompleted
                                  ? Colors.white
                                  : (isActive
                                      ? const Color(0xFF00C8FF)
                                      : const Color(0xFF6B7FA8)),
                              fontSize: 14,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : (isCompleted
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                            ),
                          ),
                          if (isActive && widget.stageStatusMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                widget.stageStatusMessage,
                                style: const TextStyle(
                                  color: Color(0xFFFFB020),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (isActive && widget.stageMetrics != null) ...[
                            const SizedBox(height: 4),
                            _buildMetricsSubtitle(widget.stageMetrics!),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSubtitle(Map<String, dynamic> metrics) {
    final speed = metrics['speed_mbps'];
    final eta = metrics['eta_seconds'];
    final frames = metrics['selected_frames'] ?? metrics['faces_to_analyze'];
    final faces = metrics['accepted_faces'];

    final details = <String>[];
    if (speed != null) details.add('$speed MB/s');
    if (eta != null && eta > 0) details.add('${eta}s remaining');
    if (frames != null) details.add('$frames frames selected');
    if (faces != null) details.add('$faces biometric faces');

    if (details.isEmpty) return const SizedBox.shrink();

    return Text(
      details.join(' • '),
      style: const TextStyle(color: Color(0xFF00C8FF), fontSize: 11),
    );
  }
}
