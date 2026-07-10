import 'package:cloud_firestore/cloud_firestore.dart';

class ContactService {
  static final CollectionReference contactCollection =
      FirebaseFirestore.instance.collection('contact');

  static Future<void> submitContact({
    required String name,
    required String email,
    required String message,
  }) async {
    final now = Timestamp.now();

    final contactData = {
      'name': name,
      'email': email,
      'message': message,
      'createdAt': now,
      'status': 'new',
    };

    await contactCollection.add(contactData);
  }
}
