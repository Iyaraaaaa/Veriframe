import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/provider/verification_notifier.dart';
import 'package:veriframe_app/screens/report_detail_screen.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

// Theme-aware palette
class _Pal {
  final bool isDark;
  const _Pal(this.isDark);

  Color get bg => isDark ? const Color(0xFF0F1523) : const Color(0xFFFFFFFF);
  Color get surfaceMuted => isDark ? const Color(0xFF162035) : const Color(0xFFF7F8FA);
  Color get border => isDark ? const Color(0xFF1A2233) : const Color(0xFFE3E6EB);
  Color get textPrimary => isDark ? const Color(0xFFE8F0FF) : const Color(0xFF14181F);
  Color get textSecondary => isDark ? const Color(0xFF8B9DC3) : const Color(0xFF667085);
  Color get textSubtle => isDark ? const Color(0xFF6B7FA8) : const Color(0xFF98A2B3);

  static const authentic = Color(0xFF1F7A54);
  static const manipulated = Color(0xFFC1483F);
  Color get manipulatedBg => isDark ? const Color(0x33C1483F) : const Color(0xFFFBEDEC);
  static const data = Color(0xFF35608F);
  Color get dataBg => isDark ? const Color(0x33EAF1F8) : const Color(0xFFEAF1F8);

  static const mono = 'monospace';
}

class ReportsPage extends ConsumerStatefulWidget {
  final bool wrapped;
  final String? initialReportId;

  const ReportsPage({super.key, this.wrapped = true, this.initialReportId});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  String? _lastNavigatedReportId;

  _Pal get _pal => _Pal(Theme.of(context).brightness == Brightness.dark);

  Future<bool> _confirmDelete(VerificationResult result) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _pal.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _pal.manipulatedBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: _Pal.manipulated,
            size: 26,
          ),
        ),
        title: Text(
          loc.reportsDeleteTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _pal.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          loc.reportsDeleteMessage(result.mediaName ?? loc.reportsForensicVerification),
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: _pal.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: _pal.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(loc.verifyCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _Pal.manipulated,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(loc.reportsDeleteConfirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteReport(String id) async {
    final loc = AppLocalizations.of(context)!;
    try {
      await ref.read(verificationRepositoryProvider).deleteResult(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.reportsDeleted),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ReportsPage] Error deleting report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.reportsDeleteFailed(e)),
            backgroundColor: _Pal.manipulated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final initialReportId = widget.initialReportId ?? (args is String ? args : null);
    final loc = AppLocalizations.of(context)!;

    final content = Container(color: _pal.bg, child: _buildReportList(context, initialReportId));
    if (!widget.wrapped) return content;

    return MainScaffold(
      showBack: true,
      title: Text(loc.reportsTitle),
      body: content,
    );
  }

  Widget _buildReportList(BuildContext context, String? initialReportId) {
    final loc = AppLocalizations.of(context)!;
    return _uid == null
        ? _buildEmptyState(
            icon: Icons.person_outline_rounded,
            message: loc.reportsNotLoggedIn,
          )
        : StreamBuilder<List<VerificationResult>>(
            stream: ref
                .watch(verificationRepositoryProvider)
                .getHistoryStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: _Pal.data),
                );
              }
              if (snapshot.hasError) {
                return _buildEmptyState(
                  icon: Icons.error_outline_rounded,
                  message: 'Error: ${snapshot.error}',
                  iconColor: _Pal.manipulated,
                );
              }

              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.folder_open_rounded,
                  message: loc.reportsNoReports,
                );
              }

              if (initialReportId != null &&
                  _lastNavigatedReportId != initialReportId) {
                final target = reports.firstWhere(
                  (r) => r.verificationId == initialReportId,
                  orElse: () => reports.first,
                );
                _lastNavigatedReportId = initialReportId;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportDetailPage(report: target),
                      ),
                    );
                  }
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DashboardHeader(_pal),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: reports.length,
                      itemBuilder: (ctx, i) => _ReportCard(
                        report: reports[i],
                        onDelete: () async {
                          final confirmed = await _confirmDelete(reports[i]);
                          if (confirmed) {
                            _deleteReport(reports[i].verificationId);
                          }
                        },
                        pal: _pal,
                      ),
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
    Color? iconColor,
  }) {
    final color = iconColor ?? _pal.textSubtle;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: color),
            ),
            const SizedBox(height: 22),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: _pal.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Dashboard header with statistics
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader(this.pal);

  final _Pal pal;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.reportsHistoryTitle,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.reportsHistorySubtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: pal.textSubtle,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pal.dataBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: _Pal.data,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Report card â€” circular confidence ring + stamped verdict
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onDelete, required this.pal});

  final VerificationResult report;
  final Future<void> Function() onDelete;
  final _Pal pal;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isReal = report.verdict.toUpperCase() == 'AUTHENTIC';
    final statusColor = isReal ? _Pal.authentic : _Pal.manipulated;
    final displayScore = isReal
        ? report.authenticityScore
        : report.fakeProbability;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailPage(report: report),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniRing(
                  value: displayScore,
                  color: statusColor,
                  isReal: isReal,
                  trackColor: pal.surfaceMuted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.mediaName ?? loc.reportsForensicVerification,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Transform.rotate(
                            angle: -0.07,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: statusColor,
                                  width: 1.1,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                report.verdict.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${displayScore.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: _Pal.mono,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                           Icon(
                             Icons.source_rounded,
                             size: 12,
                             color: pal.textSubtle,
                           ),
                           const SizedBox(width: 5),
                           Expanded(
                             child: Text(
                               report.source.toUpperCase(),
                               style: TextStyle(
                                 fontSize: 10.5,
                                 color: pal.textSubtle,
                                 fontWeight: FontWeight.w600,
                                 letterSpacing: 0.3,
                               ),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                           const SizedBox(width: 8),
                           Icon(
                             Icons.schedule_rounded,
                             size: 12,
                             color: pal.textSubtle,
                           ),
                           const SizedBox(width: 5),
                           Text(
                             DateFormat(
                               'MMM dd, yyyy',
                             ).format(report.verifiedAt),
                             style: TextStyle(
                               fontSize: 10.5,
                               color: pal.textSubtle,
                               fontFamily: _Pal.mono,
                             ),
                           ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: pal.textSubtle,
                      ),
                      tooltip: loc.reportsDeleteTooltip,
                      onPressed: onDelete,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 2, bottom: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: pal.textSubtle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniRing extends StatelessWidget {
  const _MiniRing({
    required this.value,
    required this.color,
    required this.isReal,
    required this.trackColor,
  });
  final double value;
  final Color color;
  final bool isReal;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final fraction = (value / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(54, 54),
            painter: _MiniRingPainter(fraction: fraction, color: color, trackColor: trackColor),
          ),
          Icon(
            isReal ? Icons.verified_user_rounded : Icons.gavel_rounded,
            color: color,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  _MiniRingPainter({required this.fraction, required this.color, required this.trackColor});
  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;
    const strokeWidth = 3.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * fraction;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

