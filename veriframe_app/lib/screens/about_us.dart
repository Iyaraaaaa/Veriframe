// lib/screens/about_us.dart
import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/content_widgets.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;

    return MainScaffold(
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              icon: Icons.auto_awesome_outlined,
              tagline: loc.aboutTagline,
              title: loc.aboutHeroTitle,
              subtitle: loc.aboutTech,
            ),
            const SizedBox(height: 28),

            _StatsRow(
              stats: [
                _Stat(
                  value: loc.aboutStatVerificationsValue,
                  label: loc.aboutStatVerificationsLabel,
                ),
                _Stat(
                  value: loc.aboutStatRatingValue,
                  label: loc.aboutStatRatingLabel,
                  icon: Icons.star_rounded,
                ),
                _Stat(
                  value: loc.aboutStatUptimeValue,
                  label: loc.aboutStatUptimeLabel,
                ),
              ],
            ),
            const SizedBox(height: 36),

            _AboutRule(
              accent: c.accent,
              label: loc.aboutStoryLabel,
              body: loc.aboutStory,
            ),
            const _RuleDivider(),
            _AboutRule(
              accent: const Color(0xFF9B7EDE),
              label: loc.aboutMissionLabel,
              body: loc.aboutMission,
            ),
            const _RuleDivider(),
            _AboutRule(
              accent: const Color(0xFFE0A93E),
              label: loc.aboutVisionLabel,
              body: loc.aboutVision,
            ),
            const SizedBox(height: 32),

            _AboutValuesSection(
              label: loc.aboutValuesLabel,
              values: [
                loc.aboutValueOne,
                loc.aboutValueTwo,
                loc.aboutValueThree,
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Stat {
  const _Stat({required this.value, required this.label, this.icon});
  final String value;
  final String label;
  final IconData? icon;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.text.withOpacity(0.06), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stats[i].value,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          height: 1.0,
                        ),
                      ),
                      if (stats[i].icon != null) ...[
                        const SizedBox(width: 3),
                        Icon(stats[i].icon, size: 15, color: Colors.amber),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stats[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textSubtle,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Thin, quiet separator between narrative rules — keeps the eye moving
/// down the page without the heaviness of a full divider line.
class _RuleDivider extends StatelessWidget {
  const _RuleDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 22);
  }
}

/// Narrative block with a slim rounded accent rule instead of a full card —
/// reserves the boxed-card treatment for bounded/list content only.
class _AboutRule extends StatelessWidget {
  const _AboutRule({
    required this.accent,
    required this.label,
    required this.body,
  });
  final Color accent;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.only(top: 2, bottom: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 13.5,
                    height: 1.65,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutValuesSection extends StatelessWidget {
  const _AboutValuesSection({required this.label, required this.values});
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final valueIcons = [
      Icons.shield_outlined,
      Icons.psychology_outlined,
      Icons.auto_awesome_outlined,
    ];

    final valueTitles = [
      "Uncompromising Forensic Integrity",
      "Calibrated AI Deepfake Rigor",
      "Transparent & Actionable Intelligence",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.lightbulb_outline, size: 18, color: c.accent),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: c.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: List.generate(values.length, (i) {
                final icon = valueIcons[i % valueIcons.length];
                final title = valueTitles[i % valueTitles.length];

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: c.text.withOpacity(0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, size: 24, color: c.accent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: c.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              values[i],
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 13,
                                height: 1.5,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
