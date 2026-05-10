import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:veriframe_app/l10n/generated/app_localizations.dart';
import 'package:veriframe_app/screens/home_page.dart';
import 'package:veriframe_app/splash_screen.dart';
import 'package:veriframe_app/welcome.dart';
import 'package:veriframe_app/on_bording.dart';
import 'package:veriframe_app/login_page.dart';
import 'package:veriframe_app/signup_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en'); // default language
  bool _isDarkMode = false; // default theme

  void _changeLanguage(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    setState(() {
      _isDarkMode = isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VeriFrame',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
      ),
      home: const SplashScreen(),
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/on_boarding': (context) => const OnBoardingScreen(),
        '/login': (context) => LoginPage(
          onThemeChanged: _toggleTheme,
          onGoogleSignIn: () async {}, // Placeholder, login_page handles its own sign in
          isDarkMode: _isDarkMode,
        ),
        '/signup': (context) => SignUpPage(
          isDarkMode: _isDarkMode,
          onThemeChanged: _toggleTheme,
        ),
        '/home': (context) => HomePage(
          onLocaleChange: _changeLanguage,
          locale: _locale,
          onThemeChanged: _toggleTheme,
          isDarkMode: _isDarkMode,
        ),
      },
    );
  }
}



