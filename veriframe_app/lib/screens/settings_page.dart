// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:veriframe_app/controllers/settings_controller.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/content_widgets.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PackageInfo _info = PackageInfo(appName: 'VeriFrame', version: '', buildNumber: '', packageName: '');

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _info = info);
    } catch (_) {
      // Keep defaults on platforms where PackageInfo is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    final controller = SettingsScope.of(context);

    final languages = [
      _Lang(name: loc.english, code: 'en'),
      _Lang(name: loc.sinhala, code: 'si'),
      _Lang(name: loc.tamil, code: 'ta'),
    ];

    final themes = [
      _ThemeOpt(mode: ThemeMode.light, label: loc.settingsThemeLight, icon: Icons.wb_sunny_outlined),
      _ThemeOpt(mode: ThemeMode.dark, label: loc.settingsThemeDark, icon: Icons.nightlight_round),
      _ThemeOpt(mode: ThemeMode.system, label: loc.settingsThemeSystem, icon: Icons.settings_brightness_outlined),
    ];

    return MainScaffold(
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(loc.settingsTitle, style: TextStyle(color: c.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          // Appearance / Theme
          SectionLabel(loc.settingsAppearance),
          const SizedBox(height: 12),
          ThemedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.settingsTheme, style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(loc.settingsThemeSectionHint, style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5)),
                const SizedBox(height: 14),
                Row(
                  children: themes.map((t) {
                    final selected = controller.themeMode == t.mode;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ThemeTile(
                          option: t,
                          selected: selected,
                          onTap: () {
                            controller.setThemeMode(t.mode);
                            if (t.mode != ThemeMode.system) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc.settingsThemeUpdated), behavior: SnackBarBehavior.floating),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (controller.themeMode == ThemeMode.system) ...[
                  const SizedBox(height: 10),
                  Text(loc.settingsThemeSystemHint, style: TextStyle(color: c.textSubtle, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Language
          SectionLabel(loc.settingsLanguage),
          const SizedBox(height: 12),
          ThemedCard(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: languages.map((l) {
                final selected = controller.locale.languageCode == l.code;
                return ThemedChip(
                  label: l.name,
                  selected: selected,
                  onTap: () {
                    controller.setLocale(Locale(l.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.settingsLanguageUpdated), behavior: SnackBarBehavior.floating),
                    );
                  },
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Links
          SectionLabel(loc.aboutSection),
          const SizedBox(height: 12),
          ThemedCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LinkTile(icon: Icons.info_outline_rounded, title: loc.settingsAbout, onTap: () => Navigator.pushNamed(context, '/about')),
                ThemedDivider(),
                _LinkTile(icon: Icons.policy_outlined, title: loc.settingsPrivacy, onTap: () => Navigator.pushNamed(context, '/privacy')),
                ThemedDivider(),
                _LinkTile(icon: Icons.mail_outline_rounded, title: loc.settingsContact, onTap: () => Navigator.pushNamed(context, '/contact')),
                ThemedDivider(),
                _LinkTile(icon: Icons.new_releases_outlined, title: loc.settingsVersion, subtitle: '${_info.version} (${_info.buildNumber})', onTap: null),
                ThemedDivider(),
                _LinkTile(icon: Icons.description_outlined, title: loc.settingsLicenses, onTap: () => showLicensePage(context: context, applicationName: 'VeriFrame')),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'VERI_FRAME',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSubtle, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final _ThemeOpt option;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.12) : c.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? c.accent : c.border, width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(option.icon, color: selected ? c.accent : c.textMuted, size: 22),
            const SizedBox(height: 8),
            Text(option.label, style: TextStyle(color: selected ? c.accent : c.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _LinkTile({required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      leading: Icon(icon, color: c.accent, size: 20),
      title: Text(title, style: TextStyle(color: c.text, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(color: c.textSubtle, fontSize: 12)) : null,
      trailing: onTap != null ? Icon(Icons.arrow_forward_ios_rounded, color: c.textSubtle, size: 14) : null,
      onTap: onTap,
    );
  }
}

class _Lang {
  final String name;
  final String code;
  const _Lang({required this.name, required this.code});
}

class _ThemeOpt {
  final ThemeMode mode;
  final String label;
  final IconData icon;
  const _ThemeOpt({required this.mode, required this.label, required this.icon});
}
