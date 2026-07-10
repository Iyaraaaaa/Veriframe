import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');

  // Create or update user profile data during signup/sign-in
  static Future<void> createUser({
    required String uid,
    required String email,
    String? name,
    String? profileImageBase64,
    String? googlePhotoUrl,
    bool isGoogleSignIn = false,
  }) async {
    final now = Timestamp.now();
    final currentUser = FirebaseAuth.instance.currentUser;

    // Handle name - priority: provided name -> Firebase Auth displayName -> extract from email
    String finalName = '';
    if (name != null && name.trim().isNotEmpty) {
      finalName = name.trim();
    } else if (currentUser?.displayName != null && currentUser!.displayName!.trim().isNotEmpty) {
      finalName = currentUser.displayName!.trim();
    } else {
      finalName = _extractNameFromEmail(email);
    }

    final userData = {
      'uid': uid,
      'email': email,
      'name': finalName,
      'createdAt': now,
      'updatedAt': now,
      'isActive': true,
      'signInMethod': isGoogleSignIn ? 'google' : 'email',
      'lastActive': now,
    };

    // Handle profile image - FIXED: Better null/empty handling
    String finalImageUrl = '';
    if (profileImageBase64 != null && profileImageBase64.trim().isNotEmpty) {
      userData['profileImageBase64'] = profileImageBase64.trim();
      userData['imageUrl'] = 'data:image/jpeg;base64,${profileImageBase64.trim()}';
      finalImageUrl = 'data:image/jpeg;base64,${profileImageBase64.trim()}';
    } else if (googlePhotoUrl != null && googlePhotoUrl.trim().isNotEmpty) {
      userData['profileImageBase64'] = '';
      userData['imageUrl'] = googlePhotoUrl.trim();
      finalImageUrl = googlePhotoUrl.trim();
    } else {
      // FIXED: Explicitly set empty strings to avoid null issues
      userData['profileImageBase64'] = '';
      userData['imageUrl'] = '';
      finalImageUrl = '';
    }

    try {
      // Save to Firestore
      await usersCollection.doc(uid).set(userData, SetOptions(merge: true));

      // Save to SharedPreferences for immediate access
      await _saveToSharedPreferences(uid, email, finalName, finalImageUrl);
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // Create user from Google Sign-In
  static Future<void> createUserFromGoogle(User googleUser) async {
    await createUser(
      uid: googleUser.uid,
      email: googleUser.email ?? 'unknown@gmail.com',
      name: googleUser.displayName,
      googlePhotoUrl: googleUser.photoURL,
      isGoogleSignIn: true,
    );
  }

  // Update user profile (for EditProfile functionality)
  static Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? email,
    String? profileImageBase64,
    bool clearImage = false,
  }) async {
    final Map<String, dynamic> updatedData = {
      'updatedAt': Timestamp.now(),
      'lastActive': FieldValue.serverTimestamp(),
    };

    if (name != null && name.trim().isNotEmpty) {
      updatedData['name'] = name.trim();
    }

    if (email != null && email.trim().isNotEmpty) {
      updatedData['email'] = email.trim();
    }

    // FIXED: Handle profile image update with better null checks
    if (clearImage) {
      updatedData['profileImageBase64'] = '';
      updatedData['imageUrl'] = '';
    } else if (profileImageBase64 != null) {
      if (profileImageBase64.trim().isNotEmpty) {
        updatedData['profileImageBase64'] = profileImageBase64.trim();
        updatedData['imageUrl'] = 'data:image/jpeg;base64,${profileImageBase64.trim()}';
      } else {
        // If profileImageBase64 is provided but empty, clear the image
        updatedData['profileImageBase64'] = '';
        updatedData['imageUrl'] = '';
      }
    }

    try {
      // Update in Firestore
      await usersCollection.doc(uid).update(updatedData);

      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (name != null && name.trim().isNotEmpty) {
        await prefs.setString('userName', name.trim());
      }
      if (email != null && email.trim().isNotEmpty) {
        await prefs.setString('userEmail', email.trim());
      }
      
      // FIXED: Handle image update in SharedPreferences with better logic
      if (clearImage) {
        await prefs.remove('userImage');
      } else if (profileImageBase64 != null) {
        if (profileImageBase64.trim().isNotEmpty) {
          await prefs.setString('userImage', 'data:image/jpeg;base64,${profileImageBase64.trim()}');
        } else {
          await prefs.remove('userImage');
        }
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Get user profile by UID
  static Future<DocumentSnapshot> getUser(String uid) async {
    try {
      return await usersCollection.doc(uid).get();
    } catch (e) {
      print('Error fetching user from Firestore: $e');
      rethrow;
    }
  }

  // Get current user data with comprehensive fallback system
  static Future<Map<String, String>> getCurrentUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // Try to get data from Firestore first
        final userDoc = await usersCollection.doc(currentUser.uid).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            return await _processUserData(currentUser, userData);
          }
        }
        
        // If Firestore document doesn't exist, create it from Firebase Auth
        await _createUserFromFirebaseAuth(currentUser);
        return await getCurrentUserData(); // Recursive call after creation
      }
    } catch (e) {
      print('Error fetching user data from Firestore: $e');
    }

    // Fallback to SharedPreferences
    return await _getFromSharedPreferences();
  }

  // FIXED: Process and normalize user data from Firestore with better null handling
  static Future<Map<String, String>> _processUserData(
    User currentUser, 
    Map<String, dynamic> userData
  ) async {
    try {
      // Handle name with fallback hierarchy
      String finalName = '';
      final userDataName = userData['name'];
      if (userDataName != null && userDataName.toString().trim().isNotEmpty) {
        finalName = userDataName.toString().trim();
      } else if (currentUser.displayName != null && currentUser.displayName!.trim().isNotEmpty) {
        finalName = currentUser.displayName!.trim();
      } else {
        finalName = _extractNameFromEmail(currentUser.email ?? 'user@example.com');
      }

      // Handle email
      String finalEmail = '';
      final userDataEmail = userData['email'];
      if (userDataEmail != null && userDataEmail.toString().trim().isNotEmpty) {
        finalEmail = userDataEmail.toString().trim();
      } else if (currentUser.email != null && currentUser.email!.trim().isNotEmpty) {
        finalEmail = currentUser.email!.trim();
      } else {
        finalEmail = 'user@example.com';
      }

      // FIXED: Handle profile image with better null/empty checks
      String finalImageUrl = '';
      final profileImageBase64 = userData['profileImageBase64'];
      final imageUrl = userData['imageUrl'];
      
      if (profileImageBase64 != null && profileImageBase64.toString().trim().isNotEmpty) {
        finalImageUrl = 'data:image/jpeg;base64,${profileImageBase64.toString().trim()}';
      } else if (imageUrl != null && imageUrl.toString().trim().isNotEmpty) {
        finalImageUrl = imageUrl.toString().trim();
      } else if (currentUser.photoURL != null && currentUser.photoURL!.trim().isNotEmpty) {
        finalImageUrl = currentUser.photoURL!.trim();
      }
      // If all are null/empty, finalImageUrl remains empty string

      final result = {
        'userId': currentUser.uid,
        'userName': finalName,
        'userEmail': finalEmail,
        'userImage': finalImageUrl,
      };

      // Update SharedPreferences with processed data
      await _saveToSharedPreferences(
        result['userId']!,
        result['userEmail']!,
        result['userName']!,
        result['userImage']!,
      );

      // Update last active timestamp
      await updateLastActive(currentUser.uid);

      return result;
    } catch (e) {
      print('Error processing user data: $e');
      // Return safe defaults
      return {
        'userId': currentUser.uid,
        'userName': _extractNameFromEmail(currentUser.email ?? 'user@example.com'),
        'userEmail': currentUser.email ?? 'user@example.com',
        'userImage': '',
      };
    }
  }

  // Create user document from Firebase Auth data (for Google Sign-In users)
  static Future<void> _createUserFromFirebaseAuth(User currentUser) async {
    try {
      final signInMethod = currentUser.providerData.isNotEmpty 
          ? currentUser.providerData.first.providerId 
          : 'unknown';
      
      await createUser(
        uid: currentUser.uid,
        email: currentUser.email ?? 'unknown@example.com',
        name: currentUser.displayName,
        googlePhotoUrl: currentUser.photoURL,
        isGoogleSignIn: signInMethod == 'google.com',
      );
    } catch (e) {
      print('Error creating user from Firebase Auth: $e');
      rethrow;
    }
  }

  // Extract name from email address
  static String _extractNameFromEmail(String email) {
    try {
      if (email.contains('@')) {
        String namePart = email.split('@')[0];
        // Replace dots, underscores, and numbers with spaces
        namePart = namePart.replaceAll(RegExp(r'[._0-9]'), ' ');
        // Capitalize each word
        final result = namePart.split(' ')
            .where((word) => word.isNotEmpty)
            .map((word) => word.isNotEmpty 
                ? word[0].toUpperCase() + word.substring(1).toLowerCase() 
                : word)
            .join(' ');
        return result.isNotEmpty ? result : 'User';
      }
      return 'User';
    } catch (e) {
      print('Error extracting name from email: $e');
      return 'User';
    }
  }

  // FIXED: Save user data to SharedPreferences with better empty handling
  static Future<void> _saveToSharedPreferences(
    String userId,
    String userEmail,
    String userName,
    String userImage,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('userEmail', userEmail);
      await prefs.setString('userName', userName);
      
      // FIXED: Only save image if it's not empty, otherwise remove it
      if (userImage.trim().isNotEmpty) {
        await prefs.setString('userImage', userImage.trim());
      } else {
        await prefs.remove('userImage');
      }
    } catch (e) {
      print('Error saving to SharedPreferences: $e');
    }
  }

  // FIXED: Get user data from SharedPreferences with better defaults
  static Future<Map<String, String>> _getFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;
      
      return {
        'userId': prefs.getString('userId') ?? currentUser?.uid ?? '',
        'userName': prefs.getString('userName') ?? 
                   currentUser?.displayName ?? 
                   _extractNameFromEmail(currentUser?.email ?? 'user@example.com'),
        'userEmail': prefs.getString('userEmail') ?? 
                    currentUser?.email ?? 
                    'user@example.com',
        'userImage': prefs.getString('userImage') ?? '', // FIXED: Always return empty string instead of null
      };
    } catch (e) {
      print('Error loading from SharedPreferences: $e');
      return {
        'userId': '',
        'userName': 'User',
        'userEmail': 'user@example.com',
        'userImage': '',
      };
    }
  }

  // Clear all user data (for logout)
  static Future<void> clearUserData() async {
    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Error clearing user data: $e');
      rethrow;
    }
  }

  // Check if user is logged in with additional validation
  static Future<bool> isUserLoggedIn() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;
      
      // Additional check: verify user still exists in Firestore
      final userDoc = await usersCollection.doc(currentUser.uid).get();
      return userDoc.exists;
    } catch (e) {
      print('Error checking login status: $e');
      return FirebaseAuth.instance.currentUser != null;
    }
  }

  // Refresh user data from Firestore and update local storage
  static Future<Map<String, String>> refreshUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        final userDoc = await usersCollection.doc(currentUser.uid).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null) {
            return await _processUserData(currentUser, userData);
          }
        }
        
        // Create user document if it doesn't exist
        await _createUserFromFirebaseAuth(currentUser);
        return await getCurrentUserData();
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }

    // Fallback to SharedPreferences
    return await _getFromSharedPreferences();
  }

  // Listen to user data changes in real-time
  static Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return usersCollection.doc(uid).snapshots();
  }

  // Update user's last active timestamp
  static Future<void> updateLastActive(String uid) async {
    try {
      await usersCollection.doc(uid).update({
        'lastActive': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last active: $e');
    }
  }

  // Get user statistics (optional utility method)
  static Future<Map<String, dynamic>> getUserStats(String uid) async {
    try {
      final userDoc = await usersCollection.doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return {
          'createdAt': userData['createdAt'],
          'lastActive': userData['lastActive'],
          'signInMethod': userData['signInMethod'] ?? 'unknown',
          'isActive': userData['isActive'] ?? true,
        };
      }
      return {};
    } catch (e) {
      print('Error fetching user stats: $e');
      return {};
    }
  }

  // Search users (utility method for future features)
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final querySnapshot = await usersCollection
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Check if user profile is complete
  static Future<bool> isProfileComplete(String uid) async {
    try {
      final userDoc = await usersCollection.doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final name = userData['name'];
        final email = userData['email'];
        return name != null && 
               name.toString().trim().isNotEmpty &&
               email != null && 
               email.toString().trim().isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Error checking profile completeness: $e');
      return false;
    }
  }

  // ADDED: Helper method to safely get image URL
  static String getSafeImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return '';
    }
    return imageUrl.trim();
  }

  // ADDED: Helper method to check if user has profile image
  static Future<bool> hasProfileImage(String uid) async {
    try {
      final userDoc = await usersCollection.doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final profileImageBase64 = userData['profileImageBase64'];
        final imageUrl = userData['imageUrl'];
        
        return (profileImageBase64 != null && profileImageBase64.toString().trim().isNotEmpty) ||
               (imageUrl != null && imageUrl.toString().trim().isNotEmpty);
      }
      return false;
    } catch (e) {
      print('Error checking profile image: $e');
      return false;
    }
  }
}


