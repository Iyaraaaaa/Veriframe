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

    final stack = ['Flutter', 'FastAPI', 'EfficientNetB0', 'Firebase'];

    final features = [
      _Feature(
        icon: Icons.psychology_outlined,
        title: loc.aboutFeature1Title,
        body: loc.aboutFeature1Desc,
      ),
      _Feature(
        icon: Icons.visibility_outlined,
        title: loc.aboutFeature2Title,
        body: loc.aboutFeature2Desc,
      ),
      _Feature(
        icon: Icons.smartphone_outlined,
        title: loc.aboutFeature3Title,
        body: loc.aboutFeature3Desc,
      ),
      _Feature(
        icon: Icons.autorenew_rounded,
        title: loc.aboutFeature4Title,
        body: loc.aboutFeature4Desc,
      ),
    ];

    final values = [
      _Feature(
        icon: Icons.gps_fixed_rounded,
        title: loc.aboutValue1Title,
        body: loc.aboutValue1Body,
      ),
      _Feature(
        icon: Icons.visibility_outlined,
        title: loc.aboutValue2Title,
        body: loc.aboutValue2Body,
      ),
      _Feature(
        icon: Icons.lock_outline_rounded,
        title: loc.aboutValue3Title,
        body: loc.aboutValue3Body,
      ),
      _Feature(
        icon: Icons.accessibility_new_outlined,
        title: loc.aboutValue4Title,
        body: loc.aboutValue4Body,
      ),
    ];

    final apps = [
      loc.appUse1,
      loc.appUse2,
      loc.appUse3,
      loc.appUse4,
      loc.appUse5,
      loc.appUse6,
    ];

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
              subtitle: loc.aboutMission,
            ),
            const SizedBox(height: 24),

            SectionLabel(loc.aboutDifferentLabel),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FeatureCard(
                    icon: f.icon,
                    title: f.title,
                    description: f.body,
                    accent: c.accent,
                  ),
                )),

            const SizedBox(height: 12),
            SectionLabel(loc.aboutValuesLabel),
            const SizedBox(height: 12),
            ...values.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ValueTile(icon: v.icon, title: v.title, body: v.body),
                )),

            const SizedBox(height: 12),
            SectionLabel(loc.aboutTechLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stack.map((s) => ThemedChip(label: s)).toList(),
            ),

            const SizedBox(height: 20),
            SectionLabel(loc.aboutAppsLabel),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: apps.map((s) => ThemedChip(label: s)).toList(),
            ),

            const SizedBox(height: 24),
            ThemedCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VERI_FRAME',
                          style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loc.aboutVersion,
                          style: TextStyle(color: c.textSubtle, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      loc.aboutBeta,
                      style: TextStyle(
                        color: c.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
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

class _Feature {
  final IconData icon;
  final String title;
  final String body;

  const _Feature({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _ValueTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _ValueTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ThemedCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.accent.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: c.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 12,
                    height: 1.5,
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
