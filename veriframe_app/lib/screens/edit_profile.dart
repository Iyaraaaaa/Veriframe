import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/widgets/safe_avatar_widget.dart';
import 'package:veriframe_app/service/user_profile_cache.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class EditProfilePage extends StatefulWidget {
  final String? userName;  // Nullable for Google Sign-In users
  final String userEmail;  // Email is always available
  final String? userImage; // Nullable for users without profile images

  const EditProfilePage({
    super.key,
    this.userName,
    required this.userEmail,
    this.userImage,
  });

  @override
  EditProfilePageState createState() => EditProfilePageState();
}

class EditProfilePageState extends State<EditProfilePage> {
  File? _newImage;
  String? _currentImageData; // Made nullable to handle no image cases
  final ImagePicker _picker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFromWidget();
    _refreshProfileInBackground();
  }

  void _initializeFromWidget() {
    nameController.text = widget.userName?.trim() ?? _extractNameFromEmail(widget.userEmail);
    emailController.text = widget.userEmail;
    _currentImageData = (widget.userImage != null && widget.userImage!.trim().isNotEmpty)
        ? widget.userImage!.trim()
        : null;
  }

  Future<void> _refreshProfileInBackground() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            _loadNameSafely(userData, currentUser);
            _loadEmailSafely(userData, currentUser);
            _loadImageSafely(userData, currentUser);
            if (mounted) setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Background profile refresh error: $e');
    }
  }

  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _loadNameSafely(Map<String, dynamic>? userData, User currentUser) {
    try {
      String displayName = '';
      
      // Priority: Firestore -> Firebase Auth -> Widget -> Email extraction
      if (userData != null && userData['name'] != null && 
          userData['name'].toString().trim().isNotEmpty) {
        displayName = userData['name'].toString().trim();
      } else if (currentUser.displayName != null && 
                 currentUser.displayName!.trim().isNotEmpty) {
        displayName = currentUser.displayName!.trim();
      } else if (widget.userName != null && widget.userName!.trim().isNotEmpty) {
        displayName = widget.userName!.trim();
      } else {
        displayName = _extractNameFromEmail(currentUser.email ?? widget.userEmail);
      }
      
      nameController.text = displayName;
    } catch (e) {
      debugPrint('Name loading error: $e');
      nameController.text = _extractNameFromEmail(widget.userEmail);
    }
  }

  void _loadEmailSafely(Map<String, dynamic>? userData, User currentUser) {
    try {
      String email = '';
      
      // Priority: Firestore -> Firebase Auth -> Widget
      if (userData != null && userData['email'] != null && 
          userData['email'].toString().trim().isNotEmpty) {
        email = userData['email'].toString().trim();
      } else if (currentUser.email != null && currentUser.email!.trim().isNotEmpty) {
        email = currentUser.email!.trim();
      } else {
        email = widget.userEmail;
      }
      
      emailController.text = email;
    } catch (e) {
      debugPrint('Email loading error: $e');
      emailController.text = widget.userEmail;
    }
  }

  void _loadImageSafely(Map<String, dynamic>? userData, User currentUser) {
    try {
      String? imageData;
      
      // Priority: Firestore profileImageBase64 -> Firestore imageUrl -> Firebase Auth photoURL -> Widget
      if (userData != null) {
        if (userData['profileImageBase64'] != null && 
            userData['profileImageBase64'].toString().trim().isNotEmpty) {
          imageData = 'data:image/jpeg;base64,${userData['profileImageBase64']}';
        } else if (userData['imageUrl'] != null && 
                   userData['imageUrl'].toString().trim().isNotEmpty) {
          imageData = userData['imageUrl'].toString().trim();
        }
      }
      
      // Fallback to Firebase Auth photo URL
      if ((imageData == null || imageData.isEmpty) && 
          currentUser.photoURL != null && currentUser.photoURL!.trim().isNotEmpty) {
        imageData = currentUser.photoURL!.trim();
      }
      
      // Fallback to widget data
      if ((imageData == null || imageData.isEmpty) && 
          widget.userImage != null && widget.userImage!.trim().isNotEmpty) {
        imageData = widget.userImage!.trim();
      }
      
      // Set the image data (can be null)
      _currentImageData = (imageData != null && imageData.isNotEmpty) ? imageData : null;
      
    } catch (e) {
      debugPrint('Image loading error: $e');
      _currentImageData = null;
    }
  }

  String _extractNameFromEmail(String email) {
    try {
      if (email.contains('@')) {
        String namePart = email.split('@')[0];
        namePart = namePart.replaceAll(RegExp(r'[._]'), ' ');
        return namePart.split(' ')
            .map((word) => word.isNotEmpty 
                ? word[0].toUpperCase() + word.substring(1).toLowerCase() 
                : word)
            .join(' ');
      }
    } catch (e) {
      debugPrint('Name extraction error: $e');
    }
    return 'User'; // Safe fallback
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length() / 1024 / 1024;
        if (fileSize > 5) {
          _showErrorSnackbar(loc.imageSizeError);
          return;
        }
        setState(() {
          _newImage = file;
        });
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
      _showErrorSnackbar(loc.profileFailedToPickImage);
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _newImage = null;
      _currentImageData = null;
    });
    _showSuccessSnackbar(loc.profilePhotoRemoved);
  }


  Future<void> _updatePassword(String newPassword) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackbar(loc.profileUserNotAuthenticated);
        return;
      }

      if (newPassword.length < 6) {
        _showErrorSnackbar(loc.profilePasswordTooShort);
        return;
      }

      await currentUser.updatePassword(newPassword);
      _showSuccessSnackbar(loc.profilePasswordUpdatedSuccessfully);
    } on FirebaseAuthException catch (e) {
      String errorMessage = loc.profilePasswordUpdateFailed;
      if (e.code == 'requires-recent-login') {
        errorMessage = loc.profilePleaseLoginAgain;
      } else if (e.code == 'weak-password') {
        errorMessage = loc.profilePasswordTooWeak;
      }
      _showErrorSnackbar(errorMessage);
    } catch (e) {
      debugPrint('Password update error: $e');
      _showErrorSnackbar(loc.profilePasswordUpdateFailed);
    }
  }

  void _showErrorSnackbar(String message) {
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

  void _showSuccessSnackbar(String message) {
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

  Future<void> _saveChanges() async {
    final trimmedName = nameController.text.trim();

    // Validation
    if (trimmedName.isEmpty) {
      _showErrorSnackbar(loc.profileNameRequired);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackbar(loc.profileUserNotAuthenticated);
        return;
      }

      // Update password if provided
      if (passwordController.text.isNotEmpty) {
        await _updatePassword(passwordController.text);
      }

      // Update display name in Firebase Auth
      await currentUser.updateDisplayName(trimmedName);

      // Prepare user data for Firestore
      final Map<String, dynamic> userData = {
        'uid': currentUser.uid,
        'name': trimmedName,
        'email': currentUser.email,
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Handle profile image update safely
      String? finalImageData;
      try {
        if (_newImage != null) {
          // New image selected - convert to Base64
          final bytes = await _newImage!.readAsBytes();
          final base64String = base64Encode(bytes);
          userData['profileImageBase64'] = base64String;
          userData['imageUrl'] = 'data:image/jpeg;base64,$base64String';
          finalImageData = 'data:image/jpeg;base64,$base64String';
        } else if (_currentImageData != null && _currentImageData!.isNotEmpty) {
          // Keep existing image data
          if (_currentImageData!.startsWith('data:image')) {
            try {
              final base64String = _currentImageData!.split(',')[1];
              userData['profileImageBase64'] = base64String;
              userData['imageUrl'] = _currentImageData!;
              finalImageData = _currentImageData!;
            } catch (e) {
              debugPrint('Error processing base64 image: $e');
              // If base64 processing fails, store as URL
              userData['profileImageBase64'] = '';
              userData['imageUrl'] = _currentImageData!;
              finalImageData = _currentImageData!;
            }
          } else {
            // Store as URL (Google photo, etc.)
            userData['profileImageBase64'] = '';
            userData['imageUrl'] = _currentImageData!;
            finalImageData = _currentImageData!;
          }
        } else {
          // No image - explicitly set empty values
          userData['profileImageBase64'] = '';
          userData['imageUrl'] = '';
          finalImageData = null;
        }
      } catch (e) {
        debugPrint('Image processing error: $e');
        // Safe fallback - no image
        userData['profileImageBase64'] = '';
        userData['imageUrl'] = '';
        finalImageData = null;
      }

      // Update user data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(userData, SetOptions(merge: true));

      // Clear Google profile photo when user explicitly removes their custom image
      if (finalImageData == null || finalImageData.isEmpty) {
        try {
          await currentUser.updatePhotoURL(null);
        } on FirebaseAuthException catch (_) {
          debugPrint('Could not clear Google profile photo: requires-recent-login');
        }
        UserProfileCache.instance.updateCache(bytes: null, url: null);
      }

      // Update SharedPreferences for immediate access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', currentUser.uid);
      await prefs.setString('userName', trimmedName);
      await prefs.setString('userEmail', currentUser.email ?? '');
      
      if (finalImageData != null && finalImageData.isNotEmpty) {
        await prefs.setString('userImage', finalImageData);
      } else {
        await prefs.remove('userImage'); // Remove if no image
      }

      _showSuccessSnackbar(loc.profileUpdatedSuccessfully);
      
      // Wait for success message, then navigate back
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
      
    } catch (e) {
      debugPrint('Save changes error: $e');
      _showErrorSnackbar(loc.profileSaveChangesFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return MainScaffold(
      showBack: true,
      title: Text(loc.editProfile),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileImage(isDark),
            const SizedBox(height: 25),
            _buildFormFields(isDark),
            const SizedBox(height: 30),
            _buildSaveButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(bool isDark) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: _buildCircleAvatar(isDark),
        ),
        // Camera button
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: IconButton(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
              padding: const EdgeInsets.all(6),
              tooltip: loc.profileChangePhotoTooltip,
            ),
          ),
        ),
        // Remove button (only show if there's an image)
        if (_newImage != null || (_currentImageData != null && _currentImageData!.isNotEmpty))
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red[600],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: IconButton(
                onPressed: _removeImage,
                icon: const Icon(Icons.close, size: 18, color: Colors.white),
                padding: const EdgeInsets.all(6),
                tooltip: loc.profileRemovePhotoTooltip,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCircleAvatar(bool isDark) {
    if (_newImage != null) {
      return CircleAvatar(
        radius: 58,
        backgroundImage: FileImage(_newImage!),
      );
    }

    String? imageUrl;
    Uint8List? imageBytes;

    if (_currentImageData != null && _currentImageData!.isNotEmpty) {
      if (_currentImageData!.startsWith('data:image')) {
        try {
          final b64 = _currentImageData!.split(',')[1];
          imageBytes = base64Decode(b64);
        } catch (_) {}
      } else if (_currentImageData!.startsWith('http')) {
        imageUrl = _currentImageData!;
      }
    }

    return SafeAvatarWidget(
      radius: 58,
      imageUrl: imageUrl,
      imageBytes: imageBytes,
      fallbackName: nameController.text,
    );
  }

  Widget _buildFormFields(bool isDark) {
    return Column(
      children: [
        _customTextField(nameController, loc.fullName, Icons.person, isDark),
        const SizedBox(height: 15),
        _customTextField(emailController, loc.profileEmailReadOnly, Icons.email, isDark, readOnly: true),
        const SizedBox(height: 15),
        _customTextField(
          passwordController,
          loc.profileNewPasswordOptional,
          Icons.lock,
          isDark,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            onPressed: () {
              setState(() => _isPasswordVisible = !_isPasswordVisible);
            },
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900]?.withValues(alpha: 0.5) : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.blue[200]!,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: isDark ? Colors.blue[300] : Colors.blue[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.profileTipsTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '• ${loc.profileTip1}\n'
                '• ${loc.profileTip2}\n'
                '• ${loc.profileTip3}\n'
                '• ${loc.profileTip4}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _customTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    bool obscureText = false,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.white60 : Colors.blueAccent,
          size: 24,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.white,
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.grey[600],
          fontSize: 16,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.blue[400]! : Colors.blueAccent,
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
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isDark ? Colors.blue[700] : Colors.blueAccent,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: (isDark ? Colors.blue[700] : Colors.blueAccent)?.withValues(alpha: 0.3),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                loc.saveChanges,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
      ),
    );
  }
}


