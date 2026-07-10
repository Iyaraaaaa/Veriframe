import 'package:flutter/material.dart';

class VFColors {
  static const navyDeep = Color(0xFF0F1419);
  static const navyMid = Color(0xFF1A1F2B);
  static const navySurface = Color(0xFF242B38);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate600 = Color(0xFF475569);
  static const slate800 = Color(0xFF1E293B);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue50 = Color(0xFFEFF6FF);
  static const emerald600 = Color(0xFF059669);
  static const emerald50 = Color(0xFFECFDF5);
  static const amber600 = Color(0xFFD97706);
  static const amber50 = Color(0xFFFFFBEB);
  static const red600 = Color(0xFFDC2626);
  static const red50 = Color(0xFFFEF2F2);
  static const violet600 = Color(0xFF7C3AED);
  static const white = Color(0xFFFFFFFF);
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);

  static Color adaptiveBg(bool isDark) => isDark ? navyDeep : gray50;
  static Color adaptiveSurface(bool isDark) => isDark ? navyMid : white;
  static Color adaptiveCard(bool isDark) => isDark ? navySurface : white;
  static Color adaptiveText(bool isDark) => isDark ? slate200 : gray800;
  static Color adaptiveTextSecondary(bool isDark) => isDark ? slate400 : slate600;
}

class VFTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: VFColors.gray50,
      colorScheme: const ColorScheme.light(
        primary: VFColors.blue600,
        onPrimary: VFColors.white,
        secondary: VFColors.emerald600,
        onSecondary: VFColors.white,
        surface: VFColors.white,
        onSurface: VFColors.gray800,
        error: VFColors.red600,
        onError: VFColors.white,
        outline: VFColors.gray200,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VFColors.blue600,
        foregroundColor: VFColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: VFColors.white,
        surfaceTintColor: VFColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: VFColors.gray200, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: VFColors.gray200),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VFColors.gray100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VFColors.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VFColors.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VFColors.blue600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: VFColors.slate600, fontSize: 14),
        hintStyle: const TextStyle(color: VFColors.slate400, fontSize: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: VFColors.gray800, height: 1.2),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: VFColors.gray800, height: 1.3),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VFColors.gray800),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: VFColors.gray800),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: VFColors.gray800, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: VFColors.slate600, height: 1.5),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: VFColors.slate600),
      ),
      dividerTheme: const DividerThemeData(color: VFColors.gray200, thickness: 1, space: 1),
      extensions: const [AppColors.light, AppColors.dark],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: VFColors.navyDeep,
      colorScheme: const ColorScheme.dark(
        primary: VFColors.blue600,
        onPrimary: VFColors.white,
        secondary: VFColors.emerald600,
        onSecondary: VFColors.white,
        surface: VFColors.navyMid,
        onSurface: VFColors.slate200,
        error: VFColors.red600,
        onError: VFColors.white,
        outline: VFColors.gray800,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: VFColors.navyMid,
        foregroundColor: VFColors.slate200,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(color: VFColors.slate200, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: VFColors.navySurface,
        surfaceTintColor: VFColors.navySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: VFColors.gray800, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: VFColors.gray800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VFColors.navyMid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VFColors.gray800),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VFColors.gray800),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VFColors.blue600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: VFColors.slate400, fontSize: 14),
        hintStyle: const TextStyle(color: VFColors.slate400, fontSize: 14),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: VFColors.slate200, height: 1.2),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: VFColors.slate200, height: 1.3),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: VFColors.slate200),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: VFColors.slate200),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: VFColors.slate200, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: VFColors.slate400, height: 1.5),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: VFColors.slate400),
      ),
      dividerTheme: const DividerThemeData(color: VFColors.gray800, thickness: 1, space: 1),
      extensions: const [AppColors.light, AppColors.dark],
    );
  }
}

/// Semantic, theme-aware colors used across the app.
///
/// Access via [AppColors.of] (or [BuildContext.colors]). Keeps widgets free of
/// hardcoded white/black values so light and dark themes both render correctly.
class AppColors extends ThemeExtension<AppColors> {
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color accent;
  final Color onAccent;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color divider;
  final Color success;
  final Color danger;
  final Color warning;
  final List<Color> bannerGradient;
  final Color bannerText;
  final Color bannerMuted;
  final Color bannerAccent;
  final Color chipSelected;

  const AppColors({
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.accent,
    required this.onAccent,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.divider,
    required this.success,
    required this.danger,
    required this.warning,
    required this.bannerGradient,
    required this.bannerText,
    required this.bannerMuted,
    required this.bannerAccent,
    required this.chipSelected,
  });

  static const light = AppColors(
    text: VFColors.gray800,
    textMuted: VFColors.slate600,
    textSubtle: VFColors.slate400,
    accent: VFColors.blue600,
    onAccent: VFColors.white,
    surface: VFColors.white,
    surfaceVariant: VFColors.gray100,
    border: VFColors.gray200,
    divider: VFColors.gray200,
    success: VFColors.emerald600,
    danger: VFColors.red600,
    warning: VFColors.amber600,
    bannerGradient: <Color>[Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
    bannerText: VFColors.gray900,
    bannerMuted: VFColors.slate600,
    bannerAccent: VFColors.blue600,
    chipSelected: VFColors.blue50,
  );

  static const dark = AppColors(
    text: VFColors.slate200,
    textMuted: VFColors.slate400,
    textSubtle: VFColors.slate400,
    accent: VFColors.blue600,
    onAccent: VFColors.white,
    surface: VFColors.navySurface,
    surfaceVariant: VFColors.navyMid,
    border: VFColors.gray800,
    divider: VFColors.gray800,
    success: VFColors.emerald600,
    danger: VFColors.red600,
    warning: VFColors.amber600,
    bannerGradient: <Color>[Color(0xFF0F1419), Color(0xFF1A2233)],
    bannerText: VFColors.slate200,
    bannerMuted: VFColors.slate400,
    bannerAccent: VFColors.blue600,
    chipSelected: VFColors.slate800,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? AppColors.light;

  @override
  ThemeExtension<AppColors> copyWith({
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? accent,
    Color? onAccent,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? divider,
    Color? success,
    Color? danger,
    Color? warning,
    List<Color>? bannerGradient,
    Color? bannerText,
    Color? bannerMuted,
    Color? bannerAccent,
    Color? chipSelected,
  }) {
    return AppColors(
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      bannerGradient: bannerGradient ?? this.bannerGradient,
      bannerText: bannerText ?? this.bannerText,
      bannerMuted: bannerMuted ?? this.bannerMuted,
      bannerAccent: bannerAccent ?? this.bannerAccent,
      chipSelected: chipSelected ?? this.chipSelected,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return this;
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => AppColors.of(this);
}
