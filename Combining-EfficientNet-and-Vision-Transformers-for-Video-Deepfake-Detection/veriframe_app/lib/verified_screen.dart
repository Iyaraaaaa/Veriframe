import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class VerifiedScreen extends StatefulWidget {
  const VerifiedScreen({super.key});

  @override
  State<VerifiedScreen> createState() => _VerifiedScreenState();
}

class _VerifiedScreenState extends State<VerifiedScreen> {
  late Timer _timer;
  bool _isVerified = false;
  String? _email;

  @override
  void didChangeDependencies() {
    // Get email from arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _email = args?['email'] as String?;
    super.didChangeDependencies();
    // Start polling when widget is mounted
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkEmailVerified());
  }

  Future<void> _checkEmailVerified() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified) {
        setState(() => _isVerified = true);
        _timer.cancel();
        // Navigate to home or next screen
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isVerified
            ? const Text('Email verified! Redirecting...')
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _email == null
                        ? 'A verification email was sent. Please check your inbox and verify your email.'
                        : 'A verification email was sent to $_email.\nPlease check your inbox and verify your email.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}


