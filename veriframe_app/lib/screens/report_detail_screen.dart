import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Local palette â€” white background, restrained forensic-document styling.
// Kept in this file so the screen has no dependency on unseen theme files.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
  static const risk = Color(0xFFB7791F);
  static const data = Color(0xFF35608F);
  Color get dataBg => isDark ? const Color(0x33EAF1F8) : const Color(0xFFEAF1F8);
  Color get authenticBg => isDark ? const Color(0x331F7A54) : const Color(0xFFEAF6EF);

  static const mono = 'monospace';
}

class ReportDetailPage extends StatefulWidget {
  final VerificationResult report;
  const ReportDetailPage({super.key, required this.report});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  bool _generating = false;

  _Pal get _pal => _Pal(Theme.of(context).brightness == Brightness.dark);

  Future<void> _openPdf() async {
    setState(() => _generating = true);
    try {
      final file = await PdfService.instance.generateReportPdf(
        result: widget.report,
      );
      if (file != null && await file.exists()) {
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      debugPrint('[ReportDetailPage] PDF open error: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.reportErrorOpeningPdf(e.toString())),
            backgroundColor: _Pal.manipulated,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final isReal = r.verdict.toUpperCase() == 'AUTHENTIC';

    final verdictColor = isReal ? _Pal.authentic : _Pal.manipulated;
    final verdictBg = isReal ? _pal.authenticBg : _pal.manipulatedBg;
    final riskColor = r.riskLevel.toUpperCase() == 'LOW'
        ? _Pal.authentic
        : (r.riskLevel.toUpperCase() == 'MEDIUM'
              ? _Pal.risk
              : _Pal.manipulated);

    return Scaffold(
      backgroundColor: _pal.bg,
      appBar: AppBar(
        title: Text(
          'Forensic report',
          style: TextStyle(
            color: _pal.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _pal.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _pal.textPrimary,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroCard(
              report: r,
              isReal: isReal,
              verdictColor: verdictColor,
              verdictBg: verdictBg,
              riskColor: riskColor,
            ),
            const SizedBox(height: 14),
            _ConfidenceCard(
              report: r,
              verdictColor: verdictColor,
              isReal: isReal,
            ),
            const SizedBox(height: 14),
            _PipelineCard(report: r, verdictColor: verdictColor),
            const SizedBox(height: 14),
            _ExportCard(
              generating: _generating,
              onGenerate: _openPdf,
              onShare: _openPdf,
              verificationId: r.verificationId,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Shared card shell
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final _pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pal.border, width: 1),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final _pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _pal.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: _pal.textSubtle,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Hero section â€” stamped verdict + custody-line accent
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.report,
    required this.isReal,
    required this.verdictColor,
    required this.verdictBg,
    required this.riskColor,
  });

  final VerificationResult report;
  final bool isReal;
  final Color verdictColor;
  final Color verdictBg;
  final Color riskColor;

  @override
  Widget build(BuildContext context) {
    final _pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final r = report;

    Widget thumb;
    if (r.thumbnailBase64 != null && r.thumbnailBase64!.isNotEmpty) {
      try {
        thumb = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(r.thumbnailBase64!),
            width: 46,
            height: 46,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        thumb = _placeholderThumb();
      }
    } else {
      thumb = _placeholderThumb();
    }

    return _CardShell(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 2,
            bottom: 2,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    verdictColor.withValues(alpha:0.5),
                    verdictColor.withValues(alpha:0.1),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumb,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.mediaName ?? 'Forensic media scan',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: _pal.textPrimary,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'ID ${r.verificationId}',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: _Pal.mono,
                              color: _pal.textSubtle,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.rotate(
                      angle: -0.08,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: verdictColor, width: 1.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          r.verdict.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: verdictColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: _pal.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _heroMeta(
                      _pal,
                      icon: Icons.source_rounded,
                      label: 'Source',
                      value: r.source,
                    ),
                    _heroMeta(
                      _pal,
                      icon: Icons.event_rounded,
                      label: 'Verified',
                      value: DateFormat('MMM dd, yyyy').format(r.verifiedAt),
                      mono: true,
                    ),
                    _heroMeta(
                      _pal,
                      icon: Icons.flag_rounded,
                      label: 'Risk',
                      value: r.riskLevel,
                      valueColor: riskColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderThumb() => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: verdictColor.withValues(alpha:0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(
      isReal ? Icons.verified_user_rounded : Icons.gavel_rounded,
      color: verdictColor,
      size: 22,
    ),
  );

  Widget _heroMeta(_Pal pal, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool mono = false,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: pal.textSubtle),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: pal.textSubtle,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              fontFamily: mono ? _Pal.mono : null,
              color: valueColor ?? pal.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Confidence â€” circular gauge
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({
    required this.report,
    required this.verdictColor,
    required this.isReal,
  });

  final VerificationResult report;
  final Color verdictColor;
  final bool isReal;

  @override
  Widget build(BuildContext context) {
    final _pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final r = report;
    final isReal = r.verdict.toUpperCase() == 'AUTHENTIC';
    final displayScore = isReal ? r.authenticityScore : r.fakeProbability;
    return _CardShell(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CardHeader(
                  title: 'Confidence assessment',
                  subtitle: 'Fused score across verification pipelines',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _CircularGauge(
            value: displayScore,
            color: verdictColor,
            caption: isReal ? 'AUTHENTIC' : 'MANIPULATED',
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: _pal.border),
          const SizedBox(height: 16),
          _DataRow(
            icon: Icons.hub_rounded,
            title: 'Fusion confidence rating',
            subtitle:
                'Model, frame and tracking scores combined into one rating.',
            value: '${r.confidence.toStringAsFixed(1)}%',
            valueColor: _Pal.data,
          ),
        ],
      ),
    );
  }
}

class _CircularGauge extends StatelessWidget {
  const _CircularGauge({
    required this.value,
    required this.color,
    required this.caption,
  });

  final double value; // 0-100
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final _pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final fraction = (value / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(168, 168),
            painter: _GaugePainter(fraction: fraction, color: color, trackColor: _pal.surfaceMuted),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  fontFamily: _Pal.mono,
                  color: _pal.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '% confidence',
                style: TextStyle(fontSize: 11, color: _pal.textSubtle),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  caption,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction, required this.color, required this.trackColor});
  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;
    const strokeWidth = 12.0;

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
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final _pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: valueColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _pal.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: _pal.textSubtle,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: _Pal.mono,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Pipeline metrics
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.report, required this.verdictColor});
  final VerificationResult report;
  final Color verdictColor;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Pipeline metrics',
            subtitle: 'Deep-learning and structural verification checks',
          ),
          const SizedBox(height: 16),
          _MetricLine(
            icon: Icons.movie_rounded,
            title: 'Frame consistency',
            explanation:
                'Frame-by-frame color histogram correlation. Low values indicate splicing.',
            value: r.frameConsistency,
            color: verdictColor,
          ),
          const SizedBox(height: 14),
          _MetricLine(
            icon: Icons.face_retouching_natural_rounded,
            title: 'Biometric face tracking',
            explanation:
                'Temporal displacement variance of detected face bounding boxes.',
            value: r.trackingConfidence,
            color: verdictColor,
          ),
          const SizedBox(height: 14),
          _MetricLine(
            icon: Icons.data_object_rounded,
            title: 'Metadata validation',
            explanation:
                'Container structure, FPS range and header integrity validation.',
            value: r.metadataScore,
            color: _Pal.data,
          ),
          if (r.ocrConfidence > 0) ...[
            const SizedBox(height: 14),
            _MetricLine(
              icon: Icons.text_fields_rounded,
              title: 'OCR confidence',
              explanation:
                  'Presence and edge contour quality of static text overlays.',
              value: r.ocrConfidence,
              color: _Pal.data,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.icon,
    required this.title,
    required this.explanation,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String explanation;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final _pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final fraction = (value / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _pal.textPrimary,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: _Pal.mono,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: _pal.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          explanation,
          style: TextStyle(
            fontSize: 10.5,
            color: _pal.textSubtle,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Export
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.generating,
    required this.onGenerate,
    required this.onShare,
    required this.verificationId,
  });

  final bool generating;
  final VoidCallback onGenerate;
  final VoidCallback onShare;
  final String verificationId;

  @override
  Widget build(BuildContext context) {
    final _pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final loc = AppLocalizations.of(context)!;
    return _CardShell(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: 'Export',
            subtitle: 'Generate and share the official forensic document',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _pal.dataBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                 child: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: _Pal.data,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF forensic report',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _pal.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Signed, timestamped and court-ready export.',
                        style: TextStyle(fontSize: 11, color: _pal.textSubtle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(
                generating ? 'Compiling report...' : 'Generate forensic PDF',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _pal.textPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: generating ? null : onShare,
              icon: const Icon(Icons.share_rounded, size: 17),
              label: const Text(
                'Share report',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _pal.textPrimary,
                side: BorderSide(color: _pal.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final data = 'veriframe://report/$verificationId';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.reportIdCopied(data)),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: Text(
                loc.reportCopyId,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _pal.textSecondary,
                side: BorderSide(color: _pal.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

