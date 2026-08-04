import 'package:flutter/material.dart';
import 'package:veriframe_app/utils/theme.dart';

enum EmptyStateType {
  noReports,
  noNotifications,
  noHistory,
  noSearches,
  noResults,
}

class PremiumEmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PremiumEmptyState({
    super.key,
    required this.type,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  IconData _getIcon() {
    switch (type) {
      case EmptyStateType.noReports:
        return Icons.insert_drive_file_outlined;
      case EmptyStateType.noNotifications:
        return Icons.notifications_none_outlined;
      case EmptyStateType.noHistory:
        return Icons.history_outlined;
      case EmptyStateType.noSearches:
        return Icons.search_off_outlined;
      case EmptyStateType.noResults:
        return Icons.youtube_searched_for_outlined;
    }
  }

  String _getDefaultTitle() {
    switch (type) {
      case EmptyStateType.noReports:
        return 'No Verification Reports';
      case EmptyStateType.noNotifications:
        return 'No Notifications Yet';
      case EmptyStateType.noHistory:
        return 'No History Available';
      case EmptyStateType.noSearches:
        return 'No Searches Found';
      case EmptyStateType.noResults:
        return 'No Analysis Results';
    }
  }

  String _getDefaultSubtitle() {
    switch (type) {
      case EmptyStateType.noReports:
        return 'Upload a video or image link to generate your first AI deepfake forensic report.';
      case EmptyStateType.noNotifications:
        return 'You are all caught up! New forensic alerts will appear here.';
      case EmptyStateType.noHistory:
        return 'Completed media analysis records will be stored securely in your history.';
      case EmptyStateType.noSearches:
        return 'Try adjusting your search criteria or keywords to find matching records.';
      case EmptyStateType.noResults:
        return 'Run a verification task to display detailed deepfake metrics and evidence.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final textMuted = VFColors.adaptiveTextSecondary(isDark);

    final displayTitle = title ?? _getDefaultTitle();
    final displaySubtitle = subtitle ?? _getDefaultSubtitle();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VFColors.blue600.withValues(alpha: isDark ? 0.15 : 0.08),
                border: Border.all(
                  color: VFColors.blue600.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _getIcon(),
                size: 48,
                color: VFColors.blue600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displaySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VFColors.blue600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
