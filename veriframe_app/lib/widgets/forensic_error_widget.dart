import 'package:flutter/material.dart';
import 'package:veriframe_app/utils/theme.dart';

class ForensicErrorWidget extends StatelessWidget {
  final String whatHappened;
  final String possibleReason;
  final VoidCallback? onRetry;
  final VoidCallback? onContactSupport;
  final bool isOffline;

  const ForensicErrorWidget({
    super.key,
    required this.whatHappened,
    required this.possibleReason,
    this.onRetry,
    this.onContactSupport,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final textMuted = VFColors.adaptiveTextSecondary(isDark);
    final cardBg = VFColors.adaptiveCard(isDark);
    final border = isDark ? VFColors.gray800 : VFColors.gray200;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis Interrupted',
                      style: TextStyle(
                        color: text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (isOffline)
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Text(
                            'Offline TFLite Fallback Available',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // What Happened
          _buildInfoRow(
            title: 'What happened',
            content: whatHappened,
            isDark: isDark,
            text: text,
            textMuted: textMuted,
          ),
          const SizedBox(height: 12),

          // Possible Reason
          _buildInfoRow(
            title: 'Possible reason',
            content: possibleReason,
            isDark: isDark,
            text: text,
            textMuted: textMuted,
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              if (onRetry != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Analysis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VFColors.blue600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (onRetry != null && onContactSupport != null) const SizedBox(width: 12),
              if (onContactSupport != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onContactSupport,
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: const Text('Contact Support'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: text,
                      side: BorderSide(color: border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String content,
    required bool isDark,
    required Color text,
    required Color textMuted,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? VFColors.gray800.withValues(alpha: 0.5) : VFColors.gray100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              color: text,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
