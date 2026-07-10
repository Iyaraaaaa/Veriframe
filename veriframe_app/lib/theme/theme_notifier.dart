// lib/theme/theme_notifier.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const _prefKey = 'selectedTheme';
  ThemeMode _themeMode;

  ThemeNotifier(this._themeMode);

  ThemeMode get themeMode => _themeMode;

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.name);
  }

  static Future<ThemeMode> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_prefKey) ?? 'system';
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
