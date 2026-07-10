// lib/widgets/side_menu.dart
import 'package:flutter/material.dart';
import 'package:veriframe_app/controllers/settings_controller.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/utils/theme.dart';

/// Application navigation drawer.
///
/// Theme-aware, fully localized, and navigable. Language chips update the
/// global locale instantly via [SettingsScope]; menu items route to the
/// matching page and highlight the current destination.
class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;
    final controller = SettingsScope.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;

    final items = <_DrawerItem>[
      _DrawerItem(route: '/home', icon: Icons.home_outlined, label: loc.home),
      _DrawerItem(route: '/analyze', icon: Icons.verified_user_outlined, label: loc.verify),
      _DrawerItem(route: '/about', icon: Icons.info_outline_rounded, label: loc.aboutUs),
      _DrawerItem(route: '/contact', icon: Icons.mail_outline_rounded, label: loc.contactUs),
      _DrawerItem(route: '/privacy', icon: Icons.policy_outlined, label: loc.privacyPolicy),
      _DrawerItem(route: '/settings', icon: Icons.settings_outlined, label: loc.settings),
    ];

    final languages = [
      _Lang(name: loc.english, code: 'en'),
      _Lang(name: loc.sinhala, code: 'si'),
      _Lang(name: loc.tamil, code: 'ta'),
    ];

    return Drawer(
      backgroundColor: c.surface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: c.accent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.onAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shield, color: c.onAccent, size: 24),
                ),
                const SizedBox(height: 12),
                Text('VERI_FRAME', style: TextStyle(color: c.onAccent, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(loc.drawerSubtitle, style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final item in items)
                  _DrawerTile(
                    item: item,
                    selected: currentRoute == item.route,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentRoute != item.route) {
                        Navigator.pushNamed(context, item.route);
                      }
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    loc.drawerLanguage.toUpperCase(),
                    style: TextStyle(color: c.textSubtle, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: languages.map((l) {
                      final selected = controller.locale.languageCode == l.code;
                      return ChoiceChip(
                        label: Text(l.name),
                        selected: selected,
                        onSelected: (_) => controller.setLocale(Locale(l.code)),
                        selectedColor: c.accent,
                        labelStyle: TextStyle(color: selected ? c.onAccent : c.textMuted, fontSize: 13),
                        backgroundColor: c.surfaceVariant,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
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

class _DrawerTile extends StatelessWidget {
  final _DrawerItem item;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      leading: Icon(item.icon, color: selected ? c.accent : c.textMuted),
      title: Text(item.label, style: TextStyle(color: selected ? c.accent : c.text, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, fontSize: 15)),
      selected: selected,
      selectedTileColor: c.accent.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
    );
  }
}

class _DrawerItem {
  final String route;
  final IconData icon;
  final String label;
  const _DrawerItem({required this.route, required this.icon, required this.label});
}

class _Lang {
  final String name;
  final String code;
  const _Lang({required this.name, required this.code});
}
