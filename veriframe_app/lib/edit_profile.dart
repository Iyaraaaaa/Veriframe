import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

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
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  File? _newImage;
  String? _currentImageData; // Made nullable to handle no image cases
  final ImagePicker _picker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _hasImageError = false; // Track image loading errors

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // Load from Firebase Firestore first
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          // Handle name safely
          _loadNameSafely(userData, currentUser);
          
          // Handle email safely
          _loadEmailSafely(userData, currentUser);
          
          // Handle profile image data safely
          _loadImageSafely(userData, currentUser);
        } else {
          // Use Firebase Auth and widget data if Firestore document doesn't exist
          _loadFromFirebaseAuthAndWidget(currentUser);
        }
      } else {
        // Use widget data if no current user
        _loadFromWidget();
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
      _showErrorSnackbar('Failed to load profile data');
      // Fallback to widget data
      _loadFromWidget();
    } finally {
      setState(() => _isLoading = false);
    }
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
      _hasImageError = false; // Reset error state
      
    } catch (e) {
      debugPrint('Image loading error: $e');
      _currentImageData = null;
      _hasImageError = false;
    }
  }

  void _loadFromFirebaseAuthAndWidget(User currentUser) {
    try {
      // Handle name safely
      if (currentUser.displayName != null && currentUser.displayName!.trim().isNotEmpty) {
        nameController.text = currentUser.displayName!.trim();
      } else if (widget.userName != null && widget.userName!.trim().isNotEmpty) {
        nameController.text = widget.userName!.trim();
      } else {
        nameController.text = _extractNameFromEmail(currentUser.email ?? widget.userEmail);
      }
      
      // Handle email safely
      emailController.text = currentUser.email ?? widget.userEmail;
      
      // Handle image safely
      String? imageData;
      if (currentUser.photoURL != null && currentUser.photoURL!.trim().isNotEmpty) {
        imageData = currentUser.photoURL!.trim();
      } else if (widget.userImage != null && widget.userImage!.trim().isNotEmpty) {
        imageData = widget.userImage!.trim();
      }
      
      _currentImageData = imageData;
      _hasImageError = false;
    } catch (e) {
      debugPrint('Firebase Auth loading error: $e');
      _loadFromWidget();
    }
  }

  void _loadFromWidget() {
    try {
      nameController.text = widget.userName?.trim() ?? _extractNameFromEmail(widget.userEmail);
      emailController.text = widget.userEmail;
      _currentImageData = (widget.userImage != null && widget.userImage!.trim().isNotEmpty) 
          ? widget.userImage!.trim() 
          : null;
      _hasImageError = false;
    } catch (e) {
      debugPrint('Widget loading error: $e');
      nameController.text = _extractNameFromEmail(widget.userEmail);
      emailController.text = widget.userEmail;
      _currentImageData = null;
      _hasImageError = false;
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
          _showErrorSnackbar('Image size should be less than 5MB');
          return;
        }
        setState(() {
          _newImage = file;
          _hasImageError = false; // Reset error state when new image is selected
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
    _showSuccessSnackbar('Profile photo removed');
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
      _showErrorSnackbar('Name is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showErrorSnackbar('User not authenticated');
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

      _showSuccessSnackbar('Profile updated successfully!');
      
      // Wait for success message, then navigate back
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
      title: const Text('Edit Profile'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
              tooltip: 'Change Profile Picture',
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
                tooltip: 'Remove Profile Picture',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCircleAvatar(bool isDark) {
    final imageProvider = _getImageProvider();
    
    // If we have a valid image and no error, show image only
    if (imageProvider != null && !_hasImageError) {
      return CircleAvatar(
        radius: 58,
        backgroundColor: isDark ? Colors.grey[800] : Colors.blue.shade100,
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
    
    // If no image or error, show placeholder child only
    return CircleAvatar(
      radius: 58,
      backgroundColor: isDark ? Colors.grey[800] : Colors.blue.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 40,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(height: 4),
          Text(
            _hasImageError ? 'Failed to Load' : 'No Photo',
            style: TextStyle(
              fontSize: 12,
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
      // Priority: New image -> Current image data -> null
      if (_newImage != null) {
        return FileImage(_newImage!);
      } 
      
      if (_currentImageData != null && _currentImageData!.isNotEmpty && !_hasImageError) {
        if (_currentImageData!.startsWith('data:image')) {
          // Handle Base64 images safely
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
          // Handle network images (Google Sign-In profile pictures)
          return NetworkImage(_currentImageData!);
        } else if (_currentImageData!.startsWith('assets/')) {
          // Handle asset images
          return AssetImage(_currentImageData!);
        }
      }
    } catch (e) {
      debugPrint('Image provider error: $e');
      setState(() => _hasImageError = true);
    }
    return null; // Safe return for no image
  }

  Widget _buildFormFields(bool isDark) {
    return Column(
      children: [
        _customTextField(nameController, 'Full Name', Icons.person, isDark),
        const SizedBox(height: 15),
        _customTextField(emailController, 'Email (Read-only)', Icons.email, isDark, readOnly: true),
        const SizedBox(height: 15),
        _customTextField(
          passwordController,
          'New Password (Optional)',
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
            color: isDark ? Colors.grey[900]?.withOpacity(0.5) : Colors.blue[50],
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
                      'Profile Tips:',
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
                '• Profile photo is optional - you can add, change, or remove it anytime\n'
                '• Leave password field empty if you don\'t want to change it\n'
                '• Email cannot be changed - contact support if needed\n'
                '• All other changes will be saved automatically',
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
          shadowColor: (isDark ? Colors.blue[700] : Colors.blueAccent)?.withOpacity(0.3),
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
            : const Text(
                'Save Changes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
      ),
    );
  }
}


