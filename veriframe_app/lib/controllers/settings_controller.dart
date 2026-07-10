import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central application settings: theme mode and locale.
///
/// Holds the single source of truth for the global theme and language and
/// persists both to [SharedPreferences] so they survive app restarts.
/// Any widget that depends on [SettingsScope] rebuilds when these change,
/// which makes theme and language switch instantly across the whole app.
class SettingsController extends ChangeNotifier {
  static const String _kThemeKey = 'vf_theme_mode';
  static const String _kLocaleKey = 'vf_locale';

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si'),
    Locale('ta'),
  ];

  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en');

  SettingsController() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Load persisted preferences. Safe to call multiple times.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_kThemeKey);
      if (theme != null) {
        _themeMode = switch (theme) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        };
      }
      final lang = prefs.getString(_kLocaleKey);
      if (lang != null && _isSupported(lang)) {
        _locale = Locale(lang);
      }
      notifyListeners();
    } catch (_) {
      // Ignore persistence errors and keep defaults.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system';
      await prefs.setString(_kThemeKey, value);
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    await setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocaleKey, locale.languageCode);
    } catch (_) {}
  }

  bool _isSupported(String code) =>
      supportedLocales.any((l) => l.languageCode == code);
}

/// Provides the [SettingsController] to the widget tree.
///
/// Use [SettingsScope.of] to read/update settings (rebuilds on change) or
/// [SettingsScope.controllerOf] for a non-listening lookup (e.g. in initState).
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in widget tree');
    return scope!.notifier!;
  }

  /// Non-listening lookup, safe to call from [State.initState].
  static SettingsController controllerOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in widget tree');
    return scope!.notifier!;
  }
}
