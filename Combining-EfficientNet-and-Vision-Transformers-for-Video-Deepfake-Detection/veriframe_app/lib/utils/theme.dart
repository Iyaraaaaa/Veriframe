import 'package:flutter/material.dart';

final ThemeData blackWhiteTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Colors.black,
  primaryColor: Colors.white,
  colorScheme: ColorScheme.dark(
    primary: Colors.white,
    secondary: Colors.grey,
    background: Colors.black,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 18, color: Colors.white, fontFamily: 'Roboto'),
    bodyMedium: TextStyle(fontSize: 16, color: Colors.white),
    labelLarge: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
  ),
  iconTheme: const IconThemeData(color: Colors.white),
);


