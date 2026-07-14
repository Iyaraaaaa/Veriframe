import 'package:flutter/material.dart';
import 'package:veriframe_app/controllers/settings_controller.dart';
import 'package:veriframe_app/utils/theme.dart';

/// Shared, reusable application app bar used by every main screen.
///
/// Keeps the VERIFRAME logo, title and navigation styling identical across
/// the whole app and provides the global language picker and theme toggle.
/// Brand name "VERIFRAME" is intentionally never translated.
PreferredSizeWidget globalAppBar(
  BuildContext context, {
  bool showBack = false,
  List<Widget>? extraActions,
  Widget? title,
}) {
  final controller = SettingsScope.of(context);
  final scheme = Theme.of(context).colorScheme;
  final isDark = scheme.brightness == Brightness.dark;

  final languages = const [
    _AppLanguage('English', 'en', '🇺🇸'),
    _AppLanguage('සිංහල', 'si', '🇱🇰'),
    _AppLanguage('தமிழ்', 'ta', '🇮🇳'),
  ];

  return AppBar(
    automaticallyImplyLeading: !showBack,
    leading: showBack
        ? IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onPrimary),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          )
        : null,
    title: title ??
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.onPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.shield, color: scheme.onPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'VERIFRAME',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
    backgroundColor: scheme.primary,
    foregroundColor: scheme.onPrimary,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: scheme.onPrimary),
    actions: [
      ...?extraActions,
      PopupMenuButton<Locale>(
        icon: Icon(Icons.language, color: scheme.onPrimary),
        tooltip: 'Change Language',
        onSelected: (locale) => controller.setLocale(locale),
        itemBuilder: (_) => languages
            .map(
              (l) => PopupMenuItem<Locale>(
                value: Locale(l.code),
                child: Row(
                  children: [
                    Text(l.flag),
                    const SizedBox(width: 8),
                    Text(l.name),
                  ],
                ),
              ),
            )
            .toList(),
      ),
      IconButton(
        icon: Icon(
          isDark ? Icons.wb_sunny : Icons.nightlight_round,
          color: isDark ? VFColors.amber600 : scheme.onPrimary,
        ),
        onPressed: () => controller.toggleTheme(),
        tooltip: isDark ? 'Light Mode' : 'Dark Mode',
      ),
    ],
  );
}

class _AppLanguage {
  final String name;
  final String code;
  final String flag;
  const _AppLanguage(this.name, this.code, this.flag);
}
