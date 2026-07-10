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
      _PrivacySection(
        title: loc.privacyS4Title,
        body: loc.privacyS4Body,
        points: [
          loc.privacyS4B1,
          loc.privacyS4B2,
          loc.privacyS4B3,
          loc.privacyS4B4,
        ],
      ),
      _PrivacySection(
        title: loc.privacyS5Title,
        body: loc.privacyS5Body,
        points: [
          loc.privacyS5B1,
          loc.privacyS5B2,
          loc.privacyS5B3,
          loc.privacyS5B4,
        ],
      ),
      _PrivacySection(
        title: loc.privacyS6Title,
        body: loc.privacyS6Body,
        points: const [],
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
            Container(
              margin: const EdgeInsets.only(top: 14, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.update_rounded, color: c.textSubtle, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    loc.privacyLastUpdated,
                    style: TextStyle(color: c.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final s = sections[i];
                return ThemedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: c.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.title,
                              style: TextStyle(
                                color: c.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.body,
                        style: TextStyle(
                          color: c.textMuted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                      if (s.points.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const ThemedDivider(),
                        const SizedBox(height: 12),
                        ...s.points.map((p) => BulletPoint(p)),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ThemedCard(
              accent: c.accent,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.mail_outline_rounded,
                        color: c.accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loc.privacyContact,
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: 13,
                        height: 1.55,
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
