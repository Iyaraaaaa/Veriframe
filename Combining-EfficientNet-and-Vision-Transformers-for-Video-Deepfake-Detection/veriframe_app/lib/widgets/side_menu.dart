import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/generated/app_localizations.dart';

class SideMenu extends StatelessWidget {
  final Function(Locale) onLocaleChange;
  final Locale locale;

  const SideMenu({
    Key? key,
    required this.onLocaleChange,
    required this.locale,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (t == null) return const SizedBox(); // avoid null crash

    return Drawer(
      child: Container(
        color: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black),
              child: Center(
                child: Text(
                  t.ministryName ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            _drawerItem(Icons.home, t.home ?? '', () {}),
            _drawerItem(Icons.videocam, t.services ?? '', () {}),
            _drawerItem(Icons.article, t.news ?? '', () {}),
            _drawerItem(Icons.phone, t.emergency ?? '', () {}),
            ListTile(
              leading: const Icon(Icons.language, color: Colors.white),
              title: Row(
                children: [
                  _langChip('සිංහල', 'si'),
                  _langChip('English', 'en'),
                  _langChip('தமிழ்', 'ta'),
                ],
              ),
            ),
            _drawerItem(Icons.info, t.about ?? '', () {}),
            _drawerItem(Icons.settings, t.settings ?? '', () {}),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(text, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  Widget _langChip(String label, String code) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(color: Colors.white)),
        selected: locale.languageCode == code,
        onSelected: (_) => onLocaleChange(Locale(code)),
        selectedColor: Colors.white24,
        backgroundColor: Colors.black,
      ),
    );
  }
}



