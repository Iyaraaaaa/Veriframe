import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _isLoading = true;
  List<dynamic> _reports = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = Dio();
      final baseUrl = const String.fromEnvironment('BACKEND_URL', defaultValue: 'http://10.0.2.2:3000');
      final response = await dio.get('$baseUrl/api/reports');
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _reports = (response.data as List).reversed.toList();
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Failed to load reports'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Cannot connect to server. Ensure backend is running.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context);

    return MainScaffold(
      showBack: true,
      title: const Text('Forensic Reports'),
      extraActions: [
        IconButton(onPressed: _fetchReports, icon: const Icon(Icons.refresh)),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: VFColors.red600),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(fontSize: 14), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: _fetchReports, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                  ],
                ),
              ))
              : _reports.isEmpty
                  ? Center(child: Text('No reports yet. Start an analysis to generate forensic reports.', style: t.textTheme.bodyMedium, textAlign: TextAlign.center))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (ctx, i) => _buildReportCard(_reports[i], isDark),
                    ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isDark) {
    final isManipulated = report['is_manipulated'] == true;
    final cardBg = VFColors.adaptiveCard(isDark);
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);
    final severity = report['threat_severity'] ?? 'Unknown';
    final score = report['confidence_score'] ?? 0;
    final time = report['timestamp'] ?? '';
    final filename = report['filename'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isManipulated ? VFColors.red600 : VFColors.emerald600).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(isManipulated ? Icons.warning_amber : Icons.verified, size: 16,
                  color: isManipulated ? VFColors.red600 : VFColors.emerald600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(filename, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text), overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _severityColor(severity, isDark).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(severity, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _severityColor(severity, isDark))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Confidence: ', style: TextStyle(fontSize: 12, color: muted)),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: score, minHeight: 4, backgroundColor: isDark ? VFColors.gray800 : VFColors.gray200,
                  valueColor: AlwaysStoppedAnimation(isManipulated ? VFColors.red600 : VFColors.emerald600)),
              )),
              const SizedBox(width: 8),
              Text('${(score * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
            ],
          ),
          const SizedBox(height: 6),
          Text(time.isEmpty ? 'Processing completed' : DateTime.parse(time.split('.').first).toString(), style: TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }

  Color _severityColor(String severity, bool isDark) {
    switch (severity) {
      case 'Critical': return VFColors.red600;
      case 'High': return const Color(0xFFEA580C);
      case 'Medium': return VFColors.amber600;
      case 'Low': return VFColors.emerald600;
      default: return isDark ? VFColors.slate400 : VFColors.slate600;
    }
  }
}
