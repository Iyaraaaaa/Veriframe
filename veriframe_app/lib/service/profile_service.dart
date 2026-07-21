import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String profileImageBase64;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.profileImageBase64,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImageBase64: data['profileImageBase64'] ?? '',
    );
  }
}

class ProfileService {
  final FirebaseFirestore firestore;

  ProfileService({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserProfile?> fetchUserProfile(String uid) async {
    try {
      final doc =
          await firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
}


