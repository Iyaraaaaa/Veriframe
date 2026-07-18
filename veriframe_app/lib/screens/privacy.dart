// lib/screens/privacy.dart
import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/content_widgets.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;

    final sections = <_PrivacySection>[
      _PrivacySection(
        title: loc.privacyS1Title,
        body: loc.privacyS1Body,
        points: [
          loc.privacyS1B1,
          loc.privacyS1B2,
          loc.privacyS1B3,
          loc.privacyS1B4,
        ],
      ),
      _PrivacySection(
        title: loc.privacyS2Title,
        body: loc.privacyS2Body,
        points: [
          loc.privacyS2B1,
          loc.privacyS2B2,
          loc.privacyS2B3,
          loc.privacyS2B4,
        ],
      ),
      _PrivacySection(
        title: loc.privacyS3Title,
        body: loc.privacyS3Body,
        points: [
          loc.privacyS3B1,
          loc.privacyS3B2,
          loc.privacyS3B3,
          loc.privacyS3B4,
        ],
      ),
    ];

    return MainScaffold(
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              icon: Icons.shield_outlined,
              tagline: loc.privacyTitle,
              title: loc.privacyTitle,
              subtitle: loc.privacyIntro,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.update_rounded, color: c.textSubtle, size: 13),
                const SizedBox(width: 6),
                Text(
                  loc.privacyLastUpdated,
                  style: TextStyle(
                    color: c.textSubtle,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 30),
              itemBuilder: (context, i) {
                final s = sections[i];
                return Container(
                  padding: const EdgeInsets.only(left: 14),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: c.accent, width: 2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '0${i + 1}',
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.title,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.body,
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: 13.5,
                          height: 1.65,
                        ),
                      ),
                      if (s.points.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...s.points.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: BulletPoint(p),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PrivacySection {
  final String title;
  final String body;
  final List<String> points;

  const _PrivacySection({
    required this.title,
    required this.body,
    required this.points,
  });
}
