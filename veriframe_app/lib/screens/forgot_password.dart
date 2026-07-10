import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgetPasswordPage extends StatefulWidget {
  const ForgetPasswordPage({super.key});

  @override
  _ForgetPasswordPageState createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool isLoading = false;
  bool isDarkMode = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Firebase password reset method
  Future<void> resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      _showSuccessSnackBar('Password reset email sent!');
      // Optional: Navigate back to login after successful reset
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login_page');
        }
      });
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Failed to send reset email";
      if (e.code == 'user-not-found') {
        errorMessage = "No user found with this email.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email format.";
      } else if (e.code == 'too-many-requests') {
        errorMessage = "Too many requests. Please try again later.";
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: screenHeight,
        width: screenWidth,
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
                  colors: [Color(0xFF121212), Color(0xFF424242)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF008080), Color(0xFF4F86F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Theme toggle button
              Positioned(
                top: 10,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                      color: isDarkMode ? Colors.amber : Colors.white,
                      size: 24,
                    ),
                    onPressed: () => setState(() => isDarkMode = !isDarkMode),
                  ),
                ),
              ),
              // Main content
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 600 ? screenWidth * 0.25 : 20,
                    vertical: isSmallScreen ? 20 : 40,
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: Card(
                          elevation: 20,
                          shadowColor: Colors.black.withOpacity(0.3),
                          color: isDarkMode
                              ? Colors.grey[900]?.withOpacity(0.95)
                              : Colors.white.withOpacity(0.95),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: 400,
                              minHeight: isSmallScreen ? 400 : 480,
                            ),
                            padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Title and subtitle
                                  Text(
                                    'FORGOT PASSWORD',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 24 : 28,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 4 : 8),
                                  Text(
                                    'Enter your email to reset password',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      color: isDarkMode ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 24 : 32),

                                  // Email field
                                  _buildTextField(
                                    controller: emailController,
                                    label: 'Email',
                                    prefixIcon: Icons.email_outlined,
                                    validator: _validateEmail,
                                    keyboardType: TextInputType.emailAddress,
                                    isSmallScreen: isSmallScreen,
                                  ),
                                  SizedBox(height: isSmallScreen ? 28 : 32),

                                  // Reset button
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: double.infinity,
                                    height: isSmallScreen ? 48 : 52,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : resetPassword,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D40DA),
                                        foregroundColor: Colors.white,
                                        elevation: 8,
                                        shadowColor: const Color(0xFF0D40DA).withOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              'SEND RESET LINK',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 16 : 18,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 20 : 24),

                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: isDarkMode ? Colors.white30 : Colors.black26,
                                          thickness: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            color: isDarkMode ? Colors.white60 : Colors.black54,
                                            fontWeight: FontWeight.w500,
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: isDarkMode ? Colors.white30 : Colors.black26,
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isSmallScreen ? 16 : 20),

                                  // Login link
                                  TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () => Navigator.pushReplacementNamed(context, '/login'),
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 15,
                                          color: isDarkMode ? Colors.white70 : Colors.black87,
                                        ),
                                        children: [
                                          const TextSpan(text: "Remembered your password? "),
                                          TextSpan(
                                            text: "LOGIN",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF0D40DA),
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool isSmallScreen = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
        fontSize: isSmallScreen ? 14 : 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          prefixIcon,
          color: isDarkMode ? Colors.white60 : Colors.grey[600],
          size: isSmallScreen ? 20 : 24,
        ),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black54,
          fontSize: isSmallScreen ? 14 : 16,
        ),
        filled: true,
        fillColor: isDarkMode 
            ? Colors.grey[850]?.withOpacity(0.8) 
            : Colors.grey[100]?.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black, // Black border color
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF0D40DA),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red[400]!, 
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red[400]!,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isSmallScreen ? 12 : 16,
        ),
      ),
    );
  }
}


