import 'package:flutter/material.dart';
import 'package:veriframe_app/service/engines/link_verification_engine.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/screens/report_detail_screen.dart' show ReportDetailPage;

enum TimelineStatus { completed, active, pending }

class TimelineStep {
  final String label;
  TimelineStatus status;
  String time;

  TimelineStep({
    required this.label,
    this.time = '--',
    this.status = TimelineStatus.pending,
  });
}

class DownloadAnalysisPage extends StatefulWidget {
  final String videoUrl;

  const DownloadAnalysisPage({super.key, required this.videoUrl});

  @override
  State<DownloadAnalysisPage> createState() => _DownloadAnalysisPageState();
}

class _DownloadAnalysisPageState extends State<DownloadAnalysisPage>
    with SingleTickerProviderStateMixin {
  double currentProgress = 0.0;
  int currentStageIndex = 0;
  late AnimationController _pulseController;

  String? _errorMessage;
  bool _isDone = false;

  // Mutable step list — updated live as engine emits progress
  final List<TimelineStep> steps = [
    TimelineStep(label: 'Validating URL'),
    TimelineStep(label: 'Detecting Platform'),
    TimelineStep(label: 'Downloading Video'),
    TimelineStep(label: 'Extracting Frames'),
    TimelineStep(label: 'Detecting Faces'),
    TimelineStep(label: 'Running AI Analysis'),
    TimelineStep(label: 'Generating Report'),
    TimelineStep(label: 'Verification Complete'),
  ];

  // Timestamps for when each stage starts
  final List<DateTime?> _stageTimes = List.filled(8, null);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _startVerification();
  }

  void _startVerification() async {
    try {
      final result = await LinkVerificationEngine.instance.verify(
        widget.videoUrl,
        onProgress: (int step, double progress, String message) {
          if (!mounted) return;
          setState(() {
            currentProgress = progress;
            currentStageIndex = step;

            // Mark stages completed / active / pending
            for (int i = 0; i < steps.length; i++) {
              if (i < step) {
                steps[i].status = TimelineStatus.completed;
                if (_stageTimes[i] != null) {
                  final elapsed = DateTime.now().difference(_stageTimes[i]!);
                  steps[i].time = '${elapsed.inMilliseconds / 1000.0}s';
                } else {
                  steps[i].time = 'done';
                }
              } else if (i == step) {
                if (steps[i].status != TimelineStatus.active) {
                  _stageTimes[i] = DateTime.now();
                }
                steps[i].status = TimelineStatus.active;
                steps[i].time = '...';
              } else {
                steps[i].status = TimelineStatus.pending;
                steps[i].time = '--';
              }
            }
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isDone = true;
        currentProgress = 1.0;
        // Mark all stages complete
        for (int i = 0; i < steps.length; i++) {
          steps[i].status = TimelineStatus.completed;
        }
      });

      // Auto-navigate to report after a brief pause
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailPage(report: result),
          ),
        );
      }
    } on PlatformNotSupportedException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isDone = true;
        currentProgress = currentProgress.clamp(0.0, 1.0);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verification failed: $e';
        _isDone = true;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _stageName {
    if (currentStageIndex < steps.length) {
      return steps[currentStageIndex].label;
    }
    return 'Verification Complete';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131D2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return MainScaffold(
      backgroundColor: isDark ? const Color(0xFF0B1424) : const Color(0xFFF8FAFC),
      showBack: true,
      title: const Text(
        'Video Analysis',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // Error banner (if failed)
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2D1010)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Verification Failed',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Go Back & Try Another URL',
                          style: TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Top Progress Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  // Status & Percentage Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isDone && _errorMessage == null
                                  ? 'Verification Complete'
                                  : _isDone
                                      ? 'Verification Failed'
                                      : _stageName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stage ${(currentStageIndex + 1).clamp(1, 9)} of 9',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: subtitleColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(currentProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00A3CC),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isDone ? 'Complete' : 'Processing...',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Rounded Cyan Linear Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: currentProgress,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _errorMessage != null
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF00A3CC),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Vertical Timeline Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: List.generate(
                  steps.length,
                  (index) => _buildTimelineRow(
                    step: steps[index],
                    index: index,
                    isLast: index == steps.length - 1,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor, width: 1.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'PAUSE / CANCEL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEF4444),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow({
    required TimelineStep step,
    required int index,
    required bool isLast,
    required bool isDark,
  }) {
    // Dynamic styling based on Timeline status
    Color rowBgColor;
    Color verticalLineColor;
    Color stepTextColor;
    Color timeTextColor;

    switch (step.status) {
      case TimelineStatus.completed:
        rowBgColor = isDark
            ? const Color(0xFF0A2218).withValues(alpha: 0.6)
            : const Color(0xFFF0FDF4);
        verticalLineColor = const Color(0xFF22C55E);
        stepTextColor = const Color(0xFF16A34A);
        timeTextColor = const Color(0xFF94A3B8);
        break;
      case TimelineStatus.active:
        rowBgColor = isDark
            ? const Color(0xFF082638).withValues(alpha: 0.7)
            : const Color(0xFFF0F9FF);
        verticalLineColor = const Color(0xFF00A3CC);
        stepTextColor = const Color(0xFF0077AA);
        timeTextColor = const Color(0xFF00A3CC);
        break;
      case TimelineStatus.pending:
        rowBgColor = isDark ? const Color(0xFF131D2E) : Colors.white;
        verticalLineColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        stepTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        timeTextColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: rowBgColor,
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: isDark ? const Color(0xFF1A263B) : const Color(0xFFF1F5F9),
                  width: 1.0,
                ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left continuous timeline spine
            SizedBox(
              width: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Continuous vertical line
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 14.5,
                    child: Container(
                      width: 2.5,
                      color: verticalLineColor,
                    ),
                  ),
                  // Timeline Node (Dot or Pulsing circle)
                  _buildTimelineNode(step.status),
                ],
              ),
            ),

            // Status Indicator Icon (Checkmark / Down Arrow / Hollow Circle)
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(right: 12),
              child: _buildStatusActionIcon(step.status),
            ),

            // Step Label
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: step.status == TimelineStatus.active
                        ? FontWeight.w700
                        : (step.status == TimelineStatus.completed
                            ? FontWeight.w600
                            : FontWeight.w500),
                    color: stepTextColor,
                  ),
                ),
              ),
            ),

            // Time / Duration Text on Right
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 20, 16),
              child: Text(
                step.time,
                style: TextStyle(
                  fontSize: 12,
                  color: timeTextColor,
                  fontWeight: step.status == TimelineStatus.active
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Node dot on the continuous line
  Widget _buildTimelineNode(TimelineStatus status) {
    switch (status) {
      case TimelineStatus.completed:
        return Container(
          width: 7.5,
          height: 7.5,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
        );
      case TimelineStatus.active:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 14 + (_pulseController.value * 3),
              height: 14 + (_pulseController.value * 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00A3CC).withValues(alpha: 0.25),
              ),
              child: Center(
                child: Container(
                  width: 7.5,
                  height: 7.5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00A3CC),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      case TimelineStatus.pending:
        return Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
        );
    }
  }

  // Icon in front of the text: ✓ / ↓ / ○
  Widget _buildStatusActionIcon(TimelineStatus status) {
    switch (status) {
      case TimelineStatus.completed:
        return const Icon(
          Icons.check_rounded,
          color: Color(0xFF16A34A),
          size: 17,
        );
      case TimelineStatus.active:
        return const Icon(
          Icons.arrow_downward_rounded,
          color: Color(0xFF0077AA),
          size: 16,
        );
      case TimelineStatus.pending:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF64748B),
              width: 1.5,
            ),
          ),
        );
    }
  }
}
