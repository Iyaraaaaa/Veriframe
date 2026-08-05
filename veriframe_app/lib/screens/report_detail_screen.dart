import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/verification_result.dart';

// ─────────────────────────────────────────────────────────────────────────
// Local palette — restrained forensic-document styling.
// Now fully dark-mode aware: cards, accents and shadows all adapt instead
// of the card shell being hard-locked to white.
// Kept in this file so the screen has no dependency on unseen theme files.
// ─────────────────────────────────────────────────────────────────────────
class _Pal {
  final bool isDark;
  const _Pal(this.isDark);

  Color get bg => isDark ? const Color(0xFF0F1523) : const Color(0xFFFFFFFF);

  // Card surface: a hair lighter than the page background in dark mode so
  // cards read as gently elevated instead of vanishing into the backdrop.
  Color get surface => isDark ? const Color(0xFF141C2E) : const Color(0xFFFFFFFF);
  Color get surfaceMuted => isDark ? const Color(0xFF1B2438) : const Color(0xFFF7F8FA);
  Color get border => isDark ? const Color(0xFF26314A) : const Color(0xFFE3E6EB);

  Color get textPrimary => isDark ? const Color(0xFFEEF3FF) : const Color(0xFF14181F);
  Color get textSecondary => isDark ? const Color(0xFF9FB0D1) : const Color(0xFF667085);
  Color get textSubtle => isDark ? const Color(0xFF7A8CAE) : const Color(0xFF98A2B3);

  // Accent colours are brightened slightly in dark mode so they keep enough
  // contrast against the darker surface instead of looking muddy.
  Color get authentic => isDark ? const Color(0xFF3FCB8E) : const Color(0xFF1F7A54);
  Color get manipulated => isDark ? const Color(0xFFEF6C60) : const Color(0xFFC1483F);
  Color get risk => isDark ? const Color(0xFFE0A73B) : const Color(0xFFB7791F);
  Color get data => isDark ? const Color(0xFF6FA8DC) : const Color(0xFF35608F);

  Color get manipulatedBg => isDark ? const Color(0x33EF6C60) : const Color(0xFFFBEDEC);
  Color get authenticBg => isDark ? const Color(0x333FCB8E) : const Color(0xFFEAF6EF);
  Color get dataBg => isDark ? const Color(0x336FA8DC) : const Color(0xFFEAF1F8);

  // Subtle elevation: a soft shadow in light mode, none needed in dark mode
  // where the lighter surface colour already reads as "raised".
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF14181F).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];

  static const mono = 'monospace';
}

class ReportDetailPage extends StatefulWidget {
  final VerificationResult report;
  const ReportDetailPage({super.key, required this.report});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  _Pal get _pal => _Pal(Theme.of(context).brightness == Brightness.dark);

  @override
  Widget build(BuildContext context) {
     final r = widget.report;
     final loc = AppLocalizations.of(context)!;
     final isReal = r.verdict.toUpperCase() == 'AUTHENTIC';
     final pal = _pal;

    final verdictColor = isReal ? pal.authentic : pal.manipulated;
    final verdictBg = isReal ? pal.authenticBg : pal.manipulatedBg;
    final riskColor = r.riskLevel.toUpperCase() == 'LOW'
        ? pal.authentic
        : (r.riskLevel.toUpperCase() == 'MEDIUM'
              ? pal.risk
              : pal.manipulated);

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        title: Text(
          loc.reportDetailTitle,
          style: TextStyle(
            color: pal.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: pal.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: pal.textPrimary,
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared card shell
// ─────────────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.border, width: 1),
        boxShadow: pal.cardShadow,
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
    final pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: pal.textSubtle,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Hero section — stamped verdict + custody-line accent
// ─────────────────────────────────────────────────────────────────────────

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
    final pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final loc = AppLocalizations.of(context)!;
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
                    verdictColor.withValues(alpha: 0.5),
                    verdictColor.withValues(alpha: 0.1),
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
                             r.mediaName ?? loc.reportMediaScan,
                             style: TextStyle(
                               fontSize: 15.5,
                               fontWeight: FontWeight.w700,
                               color: pal.textPrimary,
                               height: 1.25,
                             ),
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                           const SizedBox(height: 3),
                           Text(
                             loc.reportIdLabel(r.verificationId),
                             style: TextStyle(
                               fontSize: 11,
                               fontFamily: _Pal.mono,
                               color: pal.textSubtle,
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
                          color: verdictBg,
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
                Container(height: 1, color: pal.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                     _heroMeta(
                       pal,
                       icon: Icons.source_rounded,
                       label: loc.reportSourceLabel,
                       value: r.source,
                     ),
                     _heroMeta(
                       pal,
                       icon: Icons.event_rounded,
                       label: loc.reportVerifiedLabel,
                       value: DateFormat('MMM dd, yyyy').format(r.verifiedAt),
                       mono: true,
                     ),
                     _heroMeta(
                       pal,
                       icon: Icons.flag_rounded,
                       label: loc.reportRiskLabel,
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
      color: verdictColor.withValues(alpha: 0.12),
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

// ─────────────────────────────────────────────────────────────────────────
// Confidence — circular gauge
// ─────────────────────────────────────────────────────────────────────────

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
    final pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final loc = AppLocalizations.of(context)!;
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
                  title: loc.reportConfidenceAssessment,
                  subtitle: loc.reportConfidenceSubtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _CircularGauge(
            value: displayScore,
            color: verdictColor,
            caption: isReal ? loc.verifyAuthenticLabel : loc.verifyManipulatedLabel,
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: pal.border),
          const SizedBox(height: 16),
          _DataRow(
            icon: Icons.hub_rounded,
            title: loc.reportFusionConfidenceRating,
            subtitle: loc.reportFusionSubtitle,
            value: '${r.confidence.toStringAsFixed(1)}%',
            valueColor: pal.data,
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
    final pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final loc = AppLocalizations.of(context)!;
    final fraction = (value / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(168, 168),
            painter: _GaugePainter(fraction: fraction, color: color, trackColor: pal.surfaceMuted),
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
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loc.reportConfidencePercent,
                style: TextStyle(fontSize: 11, color: pal.textSubtle),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
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
    final pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.12),
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
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: pal.textSubtle,
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

// ─────────────────────────────────────────────────────────────────────────
// Pipeline metrics
// ─────────────────────────────────────────────────────────────────────────

class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.report, required this.verdictColor});
  final VerificationResult report;
  final Color verdictColor;

  @override
  Widget build(BuildContext context) {
    final pal = _Pal(Theme.of(context).brightness == Brightness.dark);
    final r = report;
    final loc = AppLocalizations.of(context)!;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: loc.reportPipelineMetrics,
            subtitle: loc.reportPipelineSubtitle,
          ),
          const SizedBox(height: 16),
          _MetricLine(
            icon: Icons.movie_rounded,
            title: loc.reportFrameConsistency,
            explanation: loc.reportFrameConsistencyExplanation,
            value: r.frameConsistency,
            color: verdictColor,
          ),
          const SizedBox(height: 14),
          _MetricLine(
            icon: Icons.face_retouching_natural_rounded,
            title: loc.reportBiometricFaceTracking,
            explanation: loc.reportBiometricExplanation,
            value: r.trackingConfidence,
            color: verdictColor,
          ),
          const SizedBox(height: 14),
          _MetricLine(
            icon: Icons.data_object_rounded,
            title: loc.reportMetadataValidation,
            explanation: loc.reportMetadataExplanation,
            value: r.metadataScore,
            color: pal.data,
          ),
          if (r.ocrConfidence > 0) ...[
            const SizedBox(height: 14),
            _MetricLine(
              icon: Icons.text_fields_rounded,
              title: loc.reportOcrConfidence,
              explanation: loc.reportOcrExplanation,
              value: r.ocrConfidence,
              color: pal.data,
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
    final pal = _Pal(Theme.of(context).brightness == Brightness.dark);
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
                  color: pal.textPrimary,
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
            backgroundColor: pal.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          explanation,
          style: TextStyle(
            fontSize: 10.5,
            color: pal.textSubtle,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}