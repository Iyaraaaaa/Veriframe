import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/report_model.dart';
import 'package:veriframe_app/service/report_service.dart';
import 'package:veriframe_app/screens/report_detail_page.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context);
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);

    return MainScaffold(
      showBack: true,
      title: const Text('Forensic Reports'),
      body: _uid == null
          ? const Center(child: Text("User not logged in."))
          : StreamBuilder<List<ReportModel>>(
              stream: ReportService.instance.getReportsStream(_uid!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: VFColors.red600),
                          const SizedBox(height: 12),
                          Text("Error: ${snapshot.error}", style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No reports yet. Start an analysis to generate forensic reports.',
                        style: t.textTheme.bodyMedium?.copyWith(color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (ctx, i) => _buildReportCard(reports[i], isDark, text, muted),
                );
              },
            ),
    );
  }

  Widget _buildReportCard(ReportModel report, bool isDark, Color text, Color muted) {
    final isReal = report.prediction == 'REAL';
    final cardBg = VFColors.adaptiveCard(isDark);
    
    // Decode base64 thumbnail if available
    Widget thumbnailWidget;
    if (report.thumbnail.isNotEmpty) {
      try {
        final bytes = base64Decode(report.thumbnail);
        thumbnailWidget = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.memory(
            bytes,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        thumbnailWidget = _buildPlaceholderThumbnail(isReal);
      }
    } else {
      thumbnailWidget = _buildPlaceholderThumbnail(isReal);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? VFColors.gray800 : VFColors.gray200),
      ),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: thumbnailWidget,
        title: Text(
          report.videoName,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isReal ? VFColors.emerald600 : VFColors.red600).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isReal ? "REAL" : "FAKE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isReal ? VFColors.emerald600 : VFColors.red600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Score: ${report.score.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(report.createdAt),
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: muted),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailPage(report: report),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderThumbnail(bool isReal) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: (isReal ? VFColors.emerald600 : VFColors.red600).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        isReal ? Icons.verified_user : Icons.gavel,
        color: isReal ? VFColors.emerald600 : VFColors.red600,
        size: 24,
      ),
    );
  }
}
