import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veriframe_app/service/user_service.dart';
import 'package:veriframe_app/service/user_profile_cache.dart';

class LoginPage extends StatefulWidget {
  final Future<void> Function(bool isDark) onThemeChanged;
  final Future<void> Function() onGoogleSignIn;
  final bool isDarkMode;

  const LoginPage({
    super.key,
    required this.onThemeChanged,
    required this.onGoogleSignIn,
    required this.isDarkMode,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Separate loading states for each button
  bool isEmailLoading = false;
  bool isGoogleLoading = false;
  bool isPasswordVisible = false;
  bool rememberMe = false;
  late bool isDarkMode;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  @override
  void initState() {
    super.initState();
    isDarkMode = widget.isDarkMode;
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRememberMe = prefs.getBool('remember_me') ?? false;
      
      if (savedRememberMe) {
        final savedEmail = prefs.getString('saved_email') ?? '';
        final savedPassword = prefs.getString('saved_password') ?? '';
        
        if (savedEmail.isNotEmpty) {
          setState(() {
            emailController.text = savedEmail;
            passwordController.text = savedPassword;
            rememberMe = savedRememberMe;
          });
        }
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveOrRemoveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (rememberMe) {
        await prefs.setString('saved_email', emailController.text.trim());
        await prefs.setString('saved_password', passwordController.text.trim());
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  Future<void> _toggleDarkMode() async {
    setState(() {
      isDarkMode = !isDarkMode;
    });
    await widget.onThemeChanged(isDarkMode);
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => isEmailLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!userCredential.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();
        _showErrorSnackBar('Please verify your email before logging in.');
        setState(() => isEmailLoading = false);
        return;
      }

      // Only save credentials for email login when remember me is checked
      await _saveOrRemoveCredentials();

      _showSuccessSnackBar('Welcome back!');
      if (mounted) {
        try {
          await UserService.getCurrentUserData();
        } catch (e) {
          debugPrint('Error caching user data: $e');
        }
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Login Failed";
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "No user found with this email.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password.";
          break;
        case 'invalid-email':
          errorMessage = "Invalid email format.";
          break;
        case 'user-disabled':
          errorMessage = "This account has been disabled.";
          break;
        case 'too-many-requests':
          errorMessage = "Too many failed attempts. Please try again later.";
          break;
        case 'invalid-credential':
          errorMessage = "Invalid email or password.";
          break;
        default:
          errorMessage = "Login failed. Please try again.";
      }
      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => isEmailLoading = false);
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() => isGoogleLoading = true);

    try {
      // Sign out from previous Google session to ensure fresh login
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        _saveGoogleUserLocally(user);
        _saveGoogleUserToFirestore(user);
      }

      _showSuccessSnackBar('Welcome back!');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Google sign-in failed';
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'This email is already associated with another sign-in method';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credentials received from Google';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google sign-in is not enabled';
          break;
        default:
          errorMessage = 'Google sign-in failed. Please try again.';
      }
      _showErrorSnackBar(errorMessage);
    } on PlatformException catch (e) {
      if (e.code != 'sign_in_canceled') {
        _showErrorSnackBar('Sign-in error: ${e.message}');
      }
    } catch (e) {
      _showErrorSnackBar('Unexpected error during Google sign-in');
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  Future<void> _saveGoogleUserLocally(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', user.uid);
      await prefs.setString('userName', user.displayName ?? 'User Name');
      await prefs.setString('userEmail', user.email ?? '');
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        await prefs.setString('userImage', user.photoURL!);
      }
      await prefs.setString('signUpMethod', 'google');

      UserProfileCache.instance.updateCache(
        name: user.displayName ?? 'User Name',
        email: user.email ?? '',
        url: user.photoURL,
      );
    } catch (e) {
      debugPrint('Error saving Google user locally: $e');
    }
  }

  Future<void> _saveGoogleUserToFirestore(User user) async {
    try {
      final userData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'name': user.displayName ?? 'User Name',
        'imageUrl': user.photoURL ?? '',
        'signUpMethod': 'google',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving Google user to Firestore: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
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
    
    // Check if any loading is happening for UI interactions
    final isAnyLoading = isEmailLoading || isGoogleLoading;

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
              Positioned(
                top: 10,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.2),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                      color: isDarkMode ? Colors.amber : Colors.white,
                      size: 24,
                    ),
                    onPressed: _toggleDarkMode,
                  ),
                ),
              ),
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
                          shadowColor: Colors.black.withValues(alpha:0.3),
                          color: isDarkMode
                              ? Colors.grey[900]?.withValues(alpha:0.95)
                              : Colors.white.withValues(alpha:0.95),
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
                                  Text(
                                    'SIGN IN',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 24 : 28,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 4 : 8),
                                  Text(
                                    'Sign in to continue',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      color: isDarkMode ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 24 : 32),

                                  TextFormField(
                                    controller: emailController,
                                    obscureText: false,
                                    validator: _validateEmail,
                                    keyboardType: TextInputType.emailAddress,
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: isSmallScreen ? 14 : 16,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: isDarkMode ? Colors.white60 : Colors.grey[600],
                                        size: isSmallScreen ? 20 : 24,
                                      ),
                                      labelStyle: TextStyle(
                                        color: isDarkMode ? Colors.white70 : Colors.black54,
                                        fontSize: isSmallScreen ? 14 : 16,
                                      ),
                                      filled: true,
                                      fillColor: isDarkMode 
                                          ? Colors.grey[850]?.withValues(alpha:0.8) 
                                          : Colors.grey[100]?.withValues(alpha:0.8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                         borderSide: BorderSide(
                                           color: isDarkMode ? Colors.grey[600]! : Colors.black,
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
                                  ),
                                  SizedBox(height: isSmallScreen ? 16 : 20),

                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: !isPasswordVisible,
                                    validator: _validatePassword,
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: isSmallScreen ? 14 : 16,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(
                                        Icons.lock_outline,
                                        color: isDarkMode ? Colors.white60 : Colors.grey[600],
                                        size: isSmallScreen ? 20 : 24,
                                      ),
                                      labelStyle: TextStyle(
                                        color: isDarkMode ? Colors.white70 : Colors.black54,
                                        fontSize: isSmallScreen ? 14 : 16,
                                      ),
                                      filled: true,
                                      fillColor: isDarkMode 
                                          ? Colors.grey[850]?.withValues(alpha:0.8) 
                                          : Colors.grey[100]?.withValues(alpha:0.8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                         borderSide: BorderSide(
                                           color: isDarkMode ? Colors.grey[600]! : Colors.black,
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
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                          color: isDarkMode ? Colors.white60 : Colors.grey[600],
                                          size: isSmallScreen ? 20 : 24,
                                        ),
                                        onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 12 : 16),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: Transform.scale(
                                              scale: 0.9,
                                              child: Checkbox(
                                                value: rememberMe,
                                                onChanged: (value) =>
                                                    setState(() => rememberMe = value ?? false),
                                                activeColor: const Color(0xFF0D40DA),
                                                checkColor: Colors.white,
                                                side: BorderSide(
                                                  color: isDarkMode ? Colors.white60 : Colors.grey[600]!,
                                                  width: 1.5,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Remember me',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 12 : 14,
                                              color: isDarkMode ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: isAnyLoading
                                            ? null
                                            : () => Navigator.pushNamed(context, '/forgot_password'),
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            color: const Color(0xFF0D40DA),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isSmallScreen ? 20 : 28),

                                  // Email Login Button
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: double.infinity,
                                    height: isSmallScreen ? 48 : 52,
                                    child: ElevatedButton(
                                      onPressed: isAnyLoading ? null : loginUser,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D40DA),
                                        foregroundColor: Colors.white,
                                        elevation: 8,
                                        shadowColor: const Color(0xFF0D40DA).withValues(alpha:0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: isEmailLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              'LOGIN',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 16 : 18,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 20 : 24),

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

                                  // Google Sign-In Button
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: double.infinity,
                                    height: isSmallScreen ? 48 : 52,
                                    child: ElevatedButton(
                                      onPressed: isAnyLoading ? null : signInWithGoogle,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
                                        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                                        elevation: 2,
                                        shadowColor: Colors.black26,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: isDarkMode ? Colors.grey[600]! : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: isGoogleLoading
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                color: isDarkMode ? Colors.white : Colors.black54,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  child: CustomPaint(
                                                    painter: GoogleIconPainter(),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'GOOGLE SIGN IN',
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 16 : 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode ? Colors.white : Colors.black87,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 16 : 24),

                                  TextButton(
                                    onPressed: isAnyLoading
                                        ? null
                                        : () => Navigator.pushNamed(context, '/signup'),
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 15,
                                          color: isDarkMode ? Colors.white70 : Colors.black87,
                                        ),
                                        children: [
                                          const TextSpan(text: "Need an account? "),
                                          TextSpan(
                                            text: "SIGN UP",
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
}

class GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Google "G" colors
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Draw the Google "G" logo
    // Blue section (top right)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57, // -90 degrees in radians
      1.57,  // 90 degrees in radians
      true,
      bluePaint,
    );
    
    // Green section (bottom right)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,     // 0 degrees
      1.57,  // 90 degrees
      true,
      greenPaint,
    );
    
    // Yellow section (bottom left)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.57,  // 90 degrees
      1.57,  // 90 degrees
      true,
      yellowPaint,
    );
    
    // Red section (top left)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14,  // 180 degrees
      1.57,  // 90 degrees
      true,
      redPaint,
    );
    
    // Draw white circle in center to create the "G" shape
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.5, whitePaint);
    
    // Draw the horizontal line to complete the "G"
    final linePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = radius * 0.2
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.7, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}



