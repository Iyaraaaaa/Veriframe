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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              icon: Icons.auto_awesome_outlined,
              tagline: loc.aboutTagline,
              title: loc.aboutHeroTitle,
              subtitle: loc.aboutTech,
            ),
            const SizedBox(height: 24),

            _StatsRow(
              stats: [
                _Stat(value: loc.aboutStatVerificationsValue, label: loc.aboutStatVerificationsLabel),
                _Stat(value: loc.aboutStatRatingValue, label: loc.aboutStatRatingLabel, icon: Icons.star_rounded),
                _Stat(value: loc.aboutStatUptimeValue, label: loc.aboutStatUptimeLabel),
              ],
            ),
            const SizedBox(height: 28),

            _AboutRule(accent: c.accent, label: loc.aboutStoryLabel, body: loc.aboutStory),
            const SizedBox(height: 20),
            _AboutRule(accent: Colors.purple, label: loc.aboutMissionLabel, body: loc.aboutMission),
            const SizedBox(height: 20),
            _AboutRule(accent: Colors.amber, label: loc.aboutVisionLabel, body: loc.aboutVision),
            const SizedBox(height: 24),

            _AboutValuesSection(
              label: loc.aboutValuesLabel,
              values: [loc.aboutValueOne, loc.aboutValueTwo, loc.aboutValueThree],
            ),
            const SizedBox(height: 16),

            ThemedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.memory_outlined, size: 18, color: c.textSubtle),
                      const SizedBox(width: 8),
                      Text(
                        loc.aboutTechLabel,
                        style: TextStyle(color: c.text, fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    loc.aboutTechBody,
                    style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.6),
                  ),
                ],
              ),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stats[i].value,
                        style: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      if (stats[i].icon != null) ...[
                        const SizedBox(width: 2),
                        Icon(stats[i].icon, size: 15, color: Colors.amber),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stats[i].label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSubtle, fontSize: 10.5, fontWeight: FontWeight.w500),
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

/// Narrative block with a colored left rule instead of a full card —
/// reserves the boxed-card treatment for bounded/list content only.
class _AboutRule extends StatelessWidget {
  const _AboutRule({required this.accent, required this.label, required this.body});
  final Color accent;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.6)),
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
    return ThemedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: c.textSubtle),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: c.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 15, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(value, style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.6)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}