import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Singleton service for instant user profile image preloading & caching.
class UserProfileCache {
  UserProfileCache._privateConstructor();
  static final UserProfileCache instance = UserProfileCache._privateConstructor();

  Uint8List? _cachedImageBytes;
  String? _cachedImageUrl;
  String _userName = '';
  String _userEmail = '';
  bool _isPreloaded = false;

  Uint8List? get cachedImageBytes => _cachedImageBytes;
  String? get cachedImageUrl => _cachedImageUrl;
  String get userName => _userName;
  String get userEmail => _userEmail;
  bool get isPreloaded => _isPreloaded;

  /// Preloads user profile data and image bytes into memory.
  Future<void> preload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('userName') ?? '';
      _userEmail = prefs.getString('userEmail') ?? '';
      _cachedImageUrl = prefs.getString('userImage');

      final base64Str = prefs.getString('profileImageBase64');
      if (base64Str != null && base64Str.isNotEmpty) {
        try {
          _cachedImageBytes = base64Decode(base64Str);
        } catch (_) {}
      }

      _isPreloaded = true;

      // Asynchronously sync latest profile data from Firebase if logged in
      _fetchFromRemote();
    } catch (e) {
      debugPrint('[UserProfileCache] Error preloading cache: $e');
    }
  }

  Future<void> _fetchFromRemote() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      _userName = currentUser.displayName ?? _userName;
      _userEmail = currentUser.email ?? _userEmail;
      if (currentUser.photoURL?.isNotEmpty == true) {
        _cachedImageUrl = currentUser.photoURL;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .timeout(const Duration(seconds: 4));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _userName = data['name'] ?? _userName;
        _userEmail = data['email'] ?? _userEmail;

        final b64 = data['profileImageBase64'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          _cachedImageBytes = base64Decode(b64);
        } else if (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty) {
          _cachedImageUrl = data['imageUrl'];
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', _userName);
      await prefs.setString('userEmail', _userEmail);
      if (_cachedImageUrl != null) await prefs.setString('userImage', _cachedImageUrl!);
      if (_cachedImageBytes != null) {
        await prefs.setString('profileImageBase64', base64Encode(_cachedImageBytes!));
      }

      // Download and cache network image bytes (e.g. Google Sign-In photoURL)
      // so that on the next app launch, preload() loads them from SharedPreferences
      // and SafeAvatarWidget renders instantly via Image.memory().
      if (_cachedImageUrl != null &&
          _cachedImageUrl!.isNotEmpty &&
          _cachedImageUrl!.startsWith('http') &&
          _cachedImageBytes == null) {
        try {
          final response = await http
              .get(Uri.parse(_cachedImageUrl!))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            _cachedImageBytes = response.bodyBytes;
            await prefs.setString(
              'profileImageBase64',
              base64Encode(_cachedImageBytes!),
            );
          }
        } catch (e) {
          debugPrint('[UserProfileCache] Error caching network image: $e');
        }
      }
    } catch (e) {
      debugPrint('[UserProfileCache] Background sync error: $e');
    }
  }

  void updateCache({String? name, String? email, Uint8List? bytes, String? url}) {
    if (name != null) _userName = name;
    if (email != null) _userEmail = email;
    if (bytes != null) {
      _cachedImageBytes = bytes;
      _cachedImageUrl = null;
    }
    if (url != null) {
      _cachedImageUrl = url;
      _cachedImageBytes = null;
    }
  }

  /// Clears all in-memory profile data after the user account is deleted.
  void clear() {
    _cachedImageBytes = null;
    _cachedImageUrl = null;
    _userName = '';
    _userEmail = '';
    _isPreloaded = false;
  }
}
