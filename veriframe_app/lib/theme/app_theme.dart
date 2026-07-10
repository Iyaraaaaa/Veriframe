// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:veriframe_app/utils/theme.dart';

/// Single source of truth for the app's light and dark themes.
///
/// Delegates to [VFTheme] so the color scheme, typography, component themes
/// and the [AppColors] extension stay consistent everywhere.
class AppTheme {
  static ThemeData lightTheme = VFTheme.light();
  static ThemeData darkTheme = VFTheme.dark();
}
