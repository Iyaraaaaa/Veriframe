import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veriframe_app/service/user_profile_cache.dart';

class UserService {
  static final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  // Create or update user profile data during signup
  static Future<void> createUser({
    required String uid,
    required String email,
    required String name,
    String? profileImageBase64,
  }) async {
    final now = Timestamp.now();

    final userData = {
      'uid': uid,
      'email': email,
      'name': name,
      'createdAt': now,
      'updatedAt': now,
      'isActive': true,
    };

    // Add profile image fields
    if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
      userData['profileImageBase64'] = profileImageBase64;
      userData['imageUrl'] = 'data:image/jpeg;base64,$profileImageBase64';
    } else {
      userData['profileImageBase64'] = '';
      userData['imageUrl'] = '';
    }

    // Save to Firestore
    await usersCollection.doc(uid).set(userData, SetOptions(merge: true));

    // Save to SharedPreferences for immediate access
    await _saveToSharedPreferences(uid, email, name, 
        profileImageBase64 != null && profileImageBase64.isNotEmpty 
            ? 'data:image/jpeg;base64,$profileImageBase64' 
            : '');
  }

  // Update user profile (for EditProfile functionality)
  static Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? profileImageBase64,
  }) async {
    final Map<String, dynamic> updatedData = {
      'updatedAt': Timestamp.now(),
    };

    if (name != null && name.isNotEmpty) {
      updatedData['name'] = name;
    }

    if (profileImageBase64 != null) {
      if (profileImageBase64.isNotEmpty) {
        updatedData['profileImageBase64'] = profileImageBase64;
        updatedData['imageUrl'] = 'data:image/jpeg;base64,$profileImageBase64';
      } else {
        updatedData['profileImageBase64'] = '';
        updatedData['imageUrl'] = '';
      }
    }

    // Update in Firestore
    await usersCollection.doc(uid).update(updatedData);

    // Update SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (name != null && name.isNotEmpty) {
      await prefs.setString('userName', name);
    }
    if (profileImageBase64 != null) {
      if (profileImageBase64.isNotEmpty) {
        await prefs.setString('userImage', 'data:image/jpeg;base64,$profileImageBase64');
      } else {
        await prefs.remove('userImage');
      }
    }
  }

  // Get user profile by UID
  static Future<DocumentSnapshot> getUser(String uid) async {
    return await usersCollection.doc(uid).get();
  }

  // Get current user data (Firebase + Firestore + SharedPreferences)
  static Future<Map<String, String>> getCurrentUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // Try to get data from Firestore first
        final userDoc = await usersCollection.doc(currentUser.uid).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            final result = {
              'userId': currentUser.uid,
              'userName': userData['name']?.toString() ?? currentUser.displayName ?? 'User Name',
              'userEmail': userData['email']?.toString() ?? currentUser.email ?? 'user@example.com',
              'userImage': '',
            };

            // Handle profile image
            if (userData['profileImageBase64'] != null && userData['profileImageBase64'].toString().isNotEmpty) {
              result['userImage'] = 'data:image/jpeg;base64,${userData['profileImageBase64']}';
            } else if (userData['imageUrl'] != null && userData['imageUrl'].toString().isNotEmpty) {
              result['userImage'] = userData['imageUrl'].toString();
            } else if (currentUser.photoURL != null && currentUser.photoURL!.isNotEmpty) {
              // Fallback to Firebase Auth photoURL (for Google sign-in)
              result['userImage'] = currentUser.photoURL!;
            }

            // Update SharedPreferences with latest data
            await _saveToSharedPreferences(
              result['userId']!,
              result['userEmail']!,
              result['userName']!,
              result['userImage']!,
            );

            return result;
          }
        }
      }
    } catch (e) {
      print('Error fetching user data from Firestore: $e');
    }

    // Fallback to SharedPreferences
    return await _getFromSharedPreferences();
  }

  // Save user data to SharedPreferences
  static Future<void> _saveToSharedPreferences(
    String userId,
    String userEmail,
    String userName,
    String userImage,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('userEmail', userEmail);
    await prefs.setString('userName', userName);
    if (userImage.isNotEmpty) {
      await prefs.setString('userImage', userImage);
    }
  }

  // Get user data from SharedPreferences
  static Future<Map<String, String>> _getFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'userId': prefs.getString('userId') ?? '',
      'userName': prefs.getString('userName') ?? 'User Name',
      'userEmail': prefs.getString('userEmail') ?? 'user@example.com',
      'userImage': prefs.getString('userImage') ?? '',
    };
  }

   // Clear user data from SharedPreferences (for logout)
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userImage');
    await prefs.remove('profileImageBase64');
    await prefs.remove('signUpMethod');
  }

  // Clear saved login credentials
  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.remove('remember_me');
  }

  // Check if user exists in Firestore
  static Future<bool> userExists(String uid) async {
    try {
      final userDoc = await usersCollection.doc(uid).get();
      return userDoc.exists;
    } catch (e) {
      print('Error checking if user exists: $e');
      return false;
    }
  }

   // Delete user account
  static Future<void> deleteUser(String uid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != uid) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user found.',
      );
    }

    try {
      // Delete Firebase Auth account first — if this requires re-auth,
      // we fail fast before wiping any local or remote data.
      await currentUser.delete();

      // Delete from Firestore
      await usersCollection.doc(uid).delete();

      // Clear SharedPreferences user data and saved credentials
      await clearUserData();
      await clearSavedCredentials();

      // Clear in-memory profile cache
      UserProfileCache.instance.clear();
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  // Update user's last active timestamp
  static Future<void> updateLastActive(String uid) async {
    try {
      await usersCollection.doc(uid).update({
        'lastActiveAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating last active: $e');
    }
  }

  // Get multiple users by their UIDs
  static Future<List<DocumentSnapshot>> getUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    
    try {
      final futures = uids.map((uid) => usersCollection.doc(uid).get());
      return await Future.wait(futures);
    } catch (e) {
      print('Error fetching multiple users: $e');
      return [];
    }
  }

  // Search users by name or email
  static Future<List<DocumentSnapshot>> searchUsers(String searchTerm) async {
    if (searchTerm.isEmpty) return [];
    
    try {
      // Search by name (case insensitive)
      final nameQuery = await usersCollection
          .where('name', isGreaterThanOrEqualTo: searchTerm)
          .where('name', isLessThanOrEqualTo: searchTerm + '\uf8ff')
          .limit(20)
          .get();
      
      // Search by email (case insensitive)
      final emailQuery = await usersCollection
          .where('email', isGreaterThanOrEqualTo: searchTerm.toLowerCase())
          .where('email', isLessThanOrEqualTo: searchTerm.toLowerCase() + '\uf8ff')
          .limit(20)
          .get();
      
      // Combine results and remove duplicates
      final allDocs = <DocumentSnapshot>[];
      final seenUids = <String>{};
      
      for (final doc in [...nameQuery.docs, ...emailQuery.docs]) {
        if (!seenUids.contains(doc.id)) {
          allDocs.add(doc);
          seenUids.add(doc.id);
        }
      }
      
      return allDocs;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
}


