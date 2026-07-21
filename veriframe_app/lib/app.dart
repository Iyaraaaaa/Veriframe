import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veriframe_app/controllers/settings_controller.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/screens/home_page.dart';
import 'package:veriframe_app/screens/on_bording.dart';
import 'package:veriframe_app/screens/login_page.dart';
import 'package:veriframe_app/screens/signup_page.dart';
import 'package:veriframe_app/screens/forgot_password.dart';
import 'package:veriframe_app/screens/verify.dart';
import 'package:veriframe_app/screens/contact_us.dart';
import 'package:veriframe_app/screens/privacy.dart';
import 'package:veriframe_app/screens/settings_page.dart';
import 'package:veriframe_app/screens/reports_page.dart';
import 'package:veriframe_app/screens/technology_stack_page.dart';
import 'package:veriframe_app/theme/app_theme.dart';
import 'package:veriframe_app/utils/navigator_key.dart';
import 'package:veriframe_app/widgets/error_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SettingsController();

    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return ErrorScreen(
        errorDetails: errorDetails,
        onRetry: () {
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
            );
          }
        },
      );
    };

    return SettingsScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            title: 'VeriFrame',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
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
            '/privacy': (_) => const PrivacyPage(),
            '/contact': (_) => const ContactUsPage(),
            '/settings': (_) => const SettingsPage(),
            '/reports': (_) => const ReportsPage(),
            '/tech_stack': (_) => const TechnologyStackPage(),
          },
        ),
      ),
    ),
  );
  }
}
