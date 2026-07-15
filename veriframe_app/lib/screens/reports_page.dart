import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:veriframe_app/models/report_model.dart';
import 'package:veriframe_app/screens/report_detail_screen.dart';
import 'package:veriframe_app/service/report_service.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ReportsPage extends StatefulWidget {
  final bool wrapped;

  const ReportsPage({super.key, this.wrapped = true});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  Future<bool> _confirmDelete(ReportModel report) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: VFColors.red600, size: 28),
        title: Text(
          'Delete Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: VFColors.adaptiveText(Theme.of(context).brightness == Brightness.dark),
          ),
        ),
        content: Text(
          'Permanently remove "${report.videoName}"? This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: VFColors.adaptiveTextSecondary(Theme.of(context).brightness == Brightness.dark),
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: VFColors.adaptiveTextSecondary(Theme.of(context).brightness == Brightness.dark),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: VFColors.red600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteReport(ReportModel report) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('reports')
          .doc(report.reportId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Report deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ReportsPage] Error deleting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't delete report: ${e.toString()}"),
            backgroundColor: VFColors.red600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildReportList(context);
    if (!widget.wrapped) return content;

    return MainScaffold(
      showBack: true,
      title: const Text('Forensic Reports'),
      body: content,
    );
  }

  Widget _buildReportList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);
    final accent = Theme.of(context).colorScheme.primary;

    return _uid == null
        ? _buildEmptyState(
            icon: Icons.person_outline_rounded,
            message: 'User not logged in.',
            isDark: isDark,
            muted: muted,
          )
        : StreamBuilder<List<ReportModel>>(
            stream: ReportService.instance.getReportsStream(_uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildEmptyState(
                  icon: Icons.error_outline_rounded,
                  message: "Error: ${snapshot.error}",
                  isDark: isDark,
                  muted: muted,
                  iconColor: VFColors.red600,
                );
              }

              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.folder_open_rounded,
                  message: 'No reports yet.\nStart an analysis to generate forensic reports.',
                  isDark: isDark,
                  muted: muted,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.description_rounded, color: accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Forensic Reports',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: text,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${reports.length} report${reports.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: reports.length,
                      itemBuilder: (ctx, i) =>
                          _buildReportCard(reports[i], isDark, text, muted, accent),
                    ),
                  ),
                ],
              );
            },
          );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required bool isDark,
    required Color muted,
    Color? iconColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (iconColor ?? muted).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: iconColor ?? muted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: muted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
    ReportModel report,
    bool isDark,
    Color text,
    Color muted,
    Color accent,
  ) {
    final isReal = report.prediction == 'REAL';
    final statusColor = isReal ? VFColors.emerald600 : VFColors.red600;
    final statusBg = isReal ? VFColors.emerald50 : VFColors.red50;
    final statusBgDark = isReal ? VFColors.emerald600.withValues(alpha: 0.15) : VFColors.red600.withValues(alpha: 0.15);

    Widget thumbnailWidget;
    if (report.thumbnail.isNotEmpty) {
      try {
        final bytes = base64Decode(report.thumbnail);
        thumbnailWidget = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
        );
      } catch (e) {
        thumbnailWidget = _buildPlaceholderThumbnail(isReal, statusColor);
      }
    } else {
      thumbnailWidget = _buildPlaceholderThumbnail(isReal, statusColor);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: VFColors.adaptiveCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? VFColors.gray800 : VFColors.gray200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReportDetailPage(report: report)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                thumbnailWidget,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.videoName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: text,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? statusBgDark : statusBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isReal ? 'REAL' : 'FAKE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${report.score.toStringAsFixed(0)}% match',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM dd, yyyy · HH:mm').format(report.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: muted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: muted),
                      tooltip: 'Delete report',
                      onPressed: () async {
                        final confirmed = await _confirmDelete(report);
                        if (confirmed) _deleteReport(report);
                      },
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: muted.withValues(alpha: 0.6)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderThumbnail(bool isReal, Color statusColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isReal ? Icons.verified_user_rounded : Icons.gavel_rounded,
        color: statusColor,
        size: 26,
      ),
    );
  }
}
