import 'package:flutter/material.dart';
import 'package:veriframe_app/models/pipeline_stage.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class PipelineTimelineWidget extends StatefulWidget {
  final int currentStageIndex;
  final bool isCompleted;

  const PipelineTimelineWidget({
    super.key,
    required this.currentStageIndex,
    this.isCompleted = false,
  });

  @override
  State<PipelineTimelineWidget> createState() => _PipelineTimelineWidgetState();
}

class _PipelineTimelineWidgetState extends State<PipelineTimelineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final textMuted = VFColors.adaptiveTextSecondary(isDark);
    final cardBg = VFColors.adaptiveCard(isDark);
    final border = isDark ? VFColors.gray800 : VFColors.gray200;
    final loc = AppLocalizations.of(context)!;
    final stages = getLocalizedVerificationStages(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.pipelineTitle,
                style: TextStyle(
                  color: text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VFColors.blue600.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.isCompleted
                      ? loc.pipelineCompleted
                      : '${widget.currentStageIndex + 1}/${stages.length}',
                  style: TextStyle(
                    color: VFColors.blue600,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final stage = stages[index];
              final isDone = widget.isCompleted || index < widget.currentStageIndex;
              final isCurrent = !widget.isCompleted && index == widget.currentStageIndex;

              Color iconColor;
              Color circleBg;
              if (isDone) {
                iconColor = Colors.white;
                circleBg = const Color(0xFF1F7A54);
              } else if (isCurrent) {
                iconColor = Colors.white;
                circleBg = VFColors.blue600;
              } else {
                iconColor = textMuted;
                circleBg = isDark ? VFColors.gray800 : VFColors.gray200;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? VFColors.blue600.withValues(alpha: isDark ? 0.15 : 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent
                        ? VFColors.blue600.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    ScaleTransition(
                      scale: isCurrent ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: circleBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone ? Icons.check_rounded : stage.icon,
                          size: 16,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                              stage.label,
                              style: TextStyle(
                                color: isDone || isCurrent ? text : textMuted,
                                fontSize: 13.5,
                                fontWeight: isCurrent ? FontWeight.w700 : (isDone ? FontWeight.w600 : FontWeight.w500),
                              ),
                            ),
                          if (isCurrent) ...[
                            const SizedBox(height: 2),
                            Text(
                              stage.description,
                              style: TextStyle(
                                color: VFColors.blue600,
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                          ],
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
}
