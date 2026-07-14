import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:veriframe_app/app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  if (Platform.isAndroid || Platform.isIOS) {
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Platform error: $error');
      debugPrint('Stack trace: $stack');
      return true;
    };
  }

  runApp(const MyApp());
}
