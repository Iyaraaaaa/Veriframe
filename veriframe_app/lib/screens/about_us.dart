// lib/screens/about_us.dart
import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/widgets/content_widgets.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

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
            const SizedBox(height: 20),

            _AboutSection(
              icon: Icons.menu_book_outlined,
              label: loc.aboutStoryLabel,
              body: loc.aboutStory,
            ),
            const SizedBox(height: 16),

            _AboutSection(
              icon: Icons.flag_outlined,
              label: loc.aboutMissionLabel,
              body: loc.aboutMission,
            ),
            const SizedBox(height: 16),

            _AboutSection(
              icon: Icons.visibility_outlined,
              label: loc.aboutVisionLabel,
              body: loc.aboutVision,
            ),
            const SizedBox(height: 16),

            _AboutValuesSection(
              label: loc.aboutValuesLabel,
              values: [
                loc.aboutValueOne,
                loc.aboutValueTwo,
                loc.aboutValueThree,
              ],
            ),
            const SizedBox(height: 16),

            _AboutSection(
              icon: Icons.memory_outlined,
              label: loc.aboutTechLabel,
              body: loc.aboutTechBody,
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
    final theme = Theme.of(context);
    return Row(
      children: [
        for (int i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        stats[i].value,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (stats[i].icon != null) ...[
                        const SizedBox(width: 2),
                        Icon(
                          stats[i].icon,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats[i].label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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

/// A single icon + label header, followed by body copy, in a themed card.
class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.icon,
    required this.label,
    required this.body,
  });

  final IconData icon;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ThemedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Values section: icon + label header, followed by a checklist of values.
class _AboutValuesSection extends StatelessWidget {
  const _AboutValuesSection({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ThemedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: theme.colorScheme.onSurface.withOpacity(0.85),
                      ),
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
