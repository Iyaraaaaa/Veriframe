import 'dart:async';
import 'package:flutter/material.dart';
import 'package:veriframe_app/models/pipeline_stage.dart';
import 'package:veriframe_app/utils/theme.dart';

class ForensicLoadingExperience extends StatefulWidget {
  final int currentStageIndex;
  final double progress;
  final String statusText;
  final VoidCallback? onCancel;

  const ForensicLoadingExperience({
    super.key,
    required this.currentStageIndex,
    required this.progress,
    required this.statusText,
    this.onCancel,
  });

  @override
  State<ForensicLoadingExperience> createState() => _ForensicLoadingExperienceState();
}

class _ForensicLoadingExperienceState extends State<ForensicLoadingExperience>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Timer _factTimer;
  int _factIndex = 0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _factTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _factIndex = (_factIndex + 1) % kForensicFacts.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _factTimer.cancel();
    super.dispose();
  }

  String _getRemainingTimeString() {
    final remainingFraction = (1.0 - widget.progress.clamp(0.0, 0.99));
    final estimatedSeconds = (remainingFraction * 12).round();
    if (estimatedSeconds <= 1) return 'Finishing verification...';
    return 'Est. ~$estimatedSeconds sec remaining';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final textMuted = VFColors.adaptiveTextSecondary(isDark);
    final cardBg = VFColors.adaptiveCard(isDark);
    final border = isDark ? VFColors.gray800 : VFColors.gray200;

    final stages = getLocalizedVerificationStages(context);
    final currentStage = (widget.currentStageIndex >= 0 &&
            widget.currentStageIndex < stages.length)
        ? stages[widget.currentStageIndex]
        : stages[0];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rotating forensic scanner graphic
          Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _rotationController,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        VFColors.blue600.withValues(alpha: 0.0),
                        VFColors.blue600.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 2),
                ),
                child: Icon(
                  currentStage.icon,
                  size: 36,
                  color: VFColors.blue600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Current Stage Title
          Text(
            currentStage.label,
            style: TextStyle(
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.statusText.isNotEmpty ? widget.statusText : currentStage.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Progress Bar with percent & estimated remaining time
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(widget.progress * 100).toInt()}%',
                    style: TextStyle(
                      color: VFColors.blue600,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _getRemainingTimeString(),
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: widget.progress.clamp(0.02, 1.0),
                  minHeight: 8,
                  backgroundColor: isDark ? VFColors.gray800 : VFColors.gray200,
                  valueColor: AlwaysStoppedAnimation<Color>(VFColors.blue600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rotating AI Facts ticker
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey<int>(_factIndex),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: VFColors.blue600.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VFColors.blue600.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: VFColors.blue600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      kForensicFacts[_factIndex],
                      style: TextStyle(
                        color: text,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (widget.onCancel != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: widget.onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
              child: const Text('Cancel Analysis'),
            ),
          ],
        ],
      ),
    );
  }
}
