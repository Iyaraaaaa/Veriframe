import 'package:flutter/material.dart';
import 'package:veriframe_app/controllers/settings_controller.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/screens/home_page.dart';
import 'package:veriframe_app/screens/on_bording.dart';
import 'package:veriframe_app/screens/login_page.dart';
import 'package:veriframe_app/screens/signup_page.dart';
import 'package:veriframe_app/forgot_password.dart';
import 'package:veriframe_app/screens/verify.dart';
import 'package:veriframe_app/screens/about_us.dart';
import 'package:veriframe_app/screens/contact_us.dart';
import 'package:veriframe_app/screens/privacy.dart';
import 'package:veriframe_app/screens/settings_page.dart';
import 'package:veriframe_app/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SettingsController();

    return SettingsScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: 'VeriFrame',
          debugShowCheckedModeBanner: false,
          locale: controller.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          themeMode: controller.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const OnBoardingScreen(),
          routes: {
            '/on_boarding': (_) => const OnBoardingScreen(),
            '/login': (_) => LoginPage(
              isDarkMode: controller.isDarkMode,
              onThemeChanged: (isDark) => controller.setThemeMode(
                isDark ? ThemeMode.dark : ThemeMode.light,
              ),
              onGoogleSignIn: () async {},
            ),
            '/signup': (_) => SignUpPage(
              isDarkMode: controller.isDarkMode,
              onThemeChanged: (isDark) => controller.setThemeMode(
                isDark ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
            '/forgot_password': (_) => const ForgetPasswordPage(),
            '/home': (_) => const HomePage(),
            '/analyze': (_) => const VerifyPage(),
            '/about': (_) => const AboutUsPage(),
            '/privacy': (_) => const PrivacyPage(),
            '/contact': (_) => const ContactUsPage(),
            '/settings': (_) => const SettingsPage(),
          },
        ),
      ),
    );
  }
}
