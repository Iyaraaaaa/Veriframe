import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/service/user_profile_cache.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class EditProfilePage extends StatefulWidget {
  final String? userName;
  final String userEmail;
  final String? userImage;

  const EditProfilePage({
    super.key,
    this.userName,
    required this.userEmail,
    this.userImage,
  });

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  File? _newImage;
  String? _currentImageData;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _hasImageError = false;

  @override
  void initState() {
    super.initState();
    _initializeFromWidget();
    _refreshProfileInBackground();
  }

  void _initializeFromWidget() {
    nameController.text =
        widget.userName?.trim() ?? _extractNameFromEmail(widget.userEmail);
    emailController.text = widget.userEmail;
    _currentImageData =
        (widget.userImage != null && widget.userImage!.trim().isNotEmpty)
        ? widget.userImage!.trim()
        : null;
    _hasImageError = false;
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

      if (userData != null &&
          userData['name'] != null &&
          userData['name'].toString().trim().isNotEmpty) {
        displayName = userData['name'].toString().trim();
      } else if (currentUser.displayName != null &&
          currentUser.displayName!.trim().isNotEmpty) {
        displayName = currentUser.displayName!.trim();
      } else if (widget.userName != null &&
          widget.userName!.trim().isNotEmpty) {
        displayName = widget.userName!.trim();
      } else {
        displayName = _extractNameFromEmail(
          currentUser.email ?? widget.userEmail,
        );
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

      if (userData != null &&
          userData['email'] != null &&
          userData['email'].toString().trim().isNotEmpty) {
        email = userData['email'].toString().trim();
      } else if (currentUser.email != null &&
          currentUser.email!.trim().isNotEmpty) {
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

      if (userData != null) {
        if (userData['profileImageBase64'] != null &&
            userData['profileImageBase64'].toString().trim().isNotEmpty) {
          imageData =
              'data:image/jpeg;base64,${userData['profileImageBase64']}';
        } else if (userData['imageUrl'] != null &&
            userData['imageUrl'].toString().trim().isNotEmpty) {
          imageData = userData['imageUrl'].toString().trim();
        }
      }

      if ((imageData == null || imageData.isEmpty) &&
          currentUser.photoURL != null &&
          currentUser.photoURL!.trim().isNotEmpty) {
        imageData = currentUser.photoURL!.trim();
      }

      if ((imageData == null || imageData.isEmpty) &&
          widget.userImage != null &&
          widget.userImage!.trim().isNotEmpty) {
        imageData = widget.userImage!.trim();
      }

      _currentImageData = (imageData != null && imageData.isNotEmpty)
          ? imageData
          : null;
      _hasImageError = false;
    } catch (e) {
      debugPrint('Image loading error: $e');
      _currentImageData = null;
      _hasImageError = false;
    }
  }

  String _extractNameFromEmail(String email) {
    try {
      if (email.contains('@')) {
        String namePart = email.split('@')[0];
        namePart = namePart.replaceAll(RegExp(r'[._]'), ' ');
        return namePart
            .split(' ')
            .map(
              (word) => word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                  : word,
            )
            .join(' ');
      }
    } catch (e) {
      debugPrint('Name extraction error: $e');
    }
    return 'User';
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
          _hasImageError = false;
        });
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
      _showErrorSnackbar('Failed to pick image');
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _newImage = null;
      _currentImageData = null;
      _hasImageError = false;
    });
    _showSuccessSnackbar(loc.profilePhotoRemoved);
  }

  Future<void> _updatePassword(String newPassword) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackbar('User not authenticated');
        return;
      }

      if (newPassword.length < 6) {
        _showErrorSnackbar('Password should be at least 6 characters');
        return;
      }

      await currentUser.updatePassword(newPassword);
      _showSuccessSnackbar('Password updated successfully!');
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to update password';
      if (e.code == 'requires-recent-login') {
        errorMessage = 'Please log in again to update your password';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      }
      _showErrorSnackbar(errorMessage);
    } catch (e) {
      debugPrint('Password update error: $e');
      _showErrorSnackbar('Failed to update password');
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
        elevation: 6,
        duration: const Duration(seconds: 3),
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
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveChanges() async {
    final trimmedName = nameController.text.trim();

    if (trimmedName.isEmpty) {
      _showErrorSnackbar(loc.profileNameRequired);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackbar('User not authenticated');
        return;
      }

      if (passwordController.text.isNotEmpty) {
        await _updatePassword(passwordController.text);
      }

      await currentUser.updateDisplayName(trimmedName);

      final Map<String, dynamic> userData = {
        'uid': currentUser.uid,
        'name': trimmedName,
        'email': currentUser.email,
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      String? finalImageData;
      try {
        if (_newImage != null) {
          final bytes = await _newImage!.readAsBytes();
          final base64String = base64Encode(bytes);
          userData['profileImageBase64'] = base64String;
          userData['imageUrl'] = 'data:image/jpeg;base64,$base64String';
          finalImageData = 'data:image/jpeg;base64,$base64String';
        } else if (_currentImageData != null && _currentImageData!.isNotEmpty) {
          if (_currentImageData!.startsWith('data:image')) {
            try {
              final base64String = _currentImageData!.split(',')[1];
              userData['profileImageBase64'] = base64String;
              userData['imageUrl'] = _currentImageData!;
              finalImageData = _currentImageData!;
            } catch (e) {
              debugPrint('Error processing base64 image: $e');
              userData['profileImageBase64'] = '';
              userData['imageUrl'] = _currentImageData!;
              finalImageData = _currentImageData!;
            }
          } else {
            userData['profileImageBase64'] = '';
            userData['imageUrl'] = _currentImageData!;
            finalImageData = _currentImageData!;
          }
        } else {
          userData['profileImageBase64'] = '';
          userData['imageUrl'] = '';
          finalImageData = null;
        }
      } catch (e) {
        debugPrint('Image processing error: $e');
        userData['profileImageBase64'] = '';
        userData['imageUrl'] = '';
        finalImageData = null;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(userData, SetOptions(merge: true));

      if (finalImageData == null || finalImageData.isEmpty) {
        try {
          await currentUser.updatePhotoURL(null);
        } on FirebaseAuthException catch (_) {
          debugPrint('Could not clear Google profile photo: requires-recent-login');
        }
        UserProfileCache.instance.updateCache(bytes: null, url: null);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', currentUser.uid);
      await prefs.setString('userName', trimmedName);
      await prefs.setString('userEmail', currentUser.email ?? '');

      if (finalImageData != null && finalImageData.isNotEmpty) {
        await prefs.setString('userImage', finalImageData);
      } else {
        await prefs.remove('userImage');
      }

      _showSuccessSnackbar(loc.profileUpdatedSuccessfully);

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save changes error: $e');
      _showErrorSnackbar('Failed to save changes');
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            _buildProfileImage(isDark),
            const SizedBox(height: 28),
            _buildFormFields(isDark),
            const SizedBox(height: 32),
            _buildSaveButton(isDark),
            const SizedBox(height: 16),
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
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.grey[600]! : Colors.grey[200]!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildCircleAvatar(isDark),
        ),
        // Camera button
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.grey[700] : Colors.blueAccent)!
                      .withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
              padding: const EdgeInsets.all(6),
              tooltip: loc.profileChangePhotoTooltip,
              splashRadius: 20,
            ),
          ),
        ),
        // Remove button
        if (_newImage != null ||
            (_currentImageData != null && _currentImageData!.isNotEmpty))
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red[500],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red[500]!.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _removeImage,
                icon: const Icon(Icons.close, size: 18, color: Colors.white),
                padding: const EdgeInsets.all(6),
                tooltip: loc.profileRemovePhotoTooltip,
                splashRadius: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCircleAvatar(bool isDark) {
    final imageProvider = _getImageProvider();

    if (imageProvider != null && !_hasImageError) {
      return CircleAvatar(
        radius: 65,
        backgroundColor: isDark ? Colors.grey[800] : Colors.blue.shade50,
        backgroundImage: imageProvider,
        onBackgroundImageError: (exception, stackTrace) {
          debugPrint('Profile image error: $exception');
          if (mounted) {
            setState(() {
              _hasImageError = true;
            });
          }
        },
      );
    }

    return CircleAvatar(
      radius: 65,
      backgroundColor: isDark ? Colors.grey[800] : Colors.blue.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 44,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
          ),
          const SizedBox(height: 6),
          Text(
            _hasImageError ? loc.profileFailedToLoad : loc.profileNoPhoto,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  ImageProvider? _getImageProvider() {
    try {
      if (_newImage != null) {
        return FileImage(_newImage!);
      }

      if (_currentImageData != null &&
          _currentImageData!.isNotEmpty &&
          !_hasImageError) {
        if (_currentImageData!.startsWith('data:image')) {
          try {
            final base64String = _currentImageData!.split(',')[1];
            final bytes = base64Decode(base64String);
            return MemoryImage(bytes);
          } catch (e) {
            debugPrint('Base64 decode error: $e');
            setState(() => _hasImageError = true);
            return null;
          }
        } else if (_currentImageData!.startsWith('http')) {
          return NetworkImage(_currentImageData!);
        } else if (_currentImageData!.startsWith('assets/')) {
          return AssetImage(_currentImageData!);
        }
      }
    } catch (e) {
      debugPrint('Image provider error: $e');
      setState(() => _hasImageError = true);
    }
    return null;
  }

  Widget _buildFormFields(bool isDark) {
    return Column(
      children: [
        _customTextField(nameController, loc.fullName, Icons.person, isDark),
        const SizedBox(height: 14),
        _customTextField(
          emailController,
          loc.profileEmailReadOnly,
          Icons.email,
          isDark,
          readOnly: true,
        ),
        const SizedBox(height: 14),
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
              size: 20,
            ),
            onPressed: () {
              setState(() => _isPasswordVisible = !_isPasswordVisible);
            },
            splashRadius: 20,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[900]?.withOpacity(0.4)
                : Colors.blue[50]?.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.blue[200]!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '• ${loc.profileTip1}\n'
                '• ${loc.profileTip2}\n'
                '• ${loc.profileTip3}\n'
                '• ${loc.profileTip4}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  height: 1.5,
                  letterSpacing: 0.2,
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
        color: readOnly
            ? (isDark ? Colors.grey[500] : Colors.grey[600])
            : (isDark ? Colors.white : Colors.black87),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.white60 : Colors.blueAccent,
          size: 22,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: readOnly
            ? (isDark ? Colors.grey[850] : Colors.grey[100])
            : (isDark ? Colors.grey[800] : Colors.white),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.blue[400]! : Colors.blueAccent,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
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
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: isDark ? Colors.blue[700] : Colors.blueAccent,
          disabledBackgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
          elevation: 4,
          shadowColor: (isDark ? Colors.blue[700] : Colors.blueAccent)
              ?.withOpacity(0.3),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                loc.saveChanges,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
      ),
    );
  }
}
