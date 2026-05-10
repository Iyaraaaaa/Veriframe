import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AffirmationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to save affirmation data to Firestore
  Future<void> saveAffirmationData(Map<String, dynamic> formData) async {
    try {
      // Save data to the 'affirmations' collection
      await _firestore.collection('affirmations').add(formData);
      debugPrint("Affirmation Data Saved Successfully");
    } catch (e) {
      debugPrint("Error saving affirmation data: $e");
      rethrow; // Rethrow error to be handled by the calling function
    }
  }

  // Method to retrieve all affirmation data from Firestore
  Future<List<Map<String, dynamic>>> getAffirmations() async {
    try {
      // Get the list of all affirmations from Firestore
      QuerySnapshot snapshot = await _firestore.collection('affirmations').get();
      List<Map<String, dynamic>> affirmations = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      return affirmations;
    } catch (e) {
      debugPrint("Error fetching affirmation data: $e");
      rethrow; // Rethrow error to be handled by the calling function
    }
  }

  // Method to update affirmation data in Firestore (optional)
  Future<void> updateAffirmationData(String docId, Map<String, dynamic> formData) async {
    try {
      // Update the affirmation data using its document ID
      await _firestore.collection('affirmations').doc(docId).update(formData);
      debugPrint("Affirmation Data Updated Successfully");
    } catch (e) {
      debugPrint("Error updating affirmation data: $e");
      rethrow; // Rethrow error to be handled by the calling function
    }
  }

  // Method to delete affirmation data from Firestore (optional)
  Future<void> deleteAffirmationData(String docId) async {
    try {
      // Delete the affirmation data using its document ID
      await _firestore.collection('affirmations').doc(docId).delete();
      print("Affirmation Data Deleted Successfully");
    } catch (e) {
      print("Error deleting affirmation data: $e");
      throw e; // Rethrow error to be handled by the calling function
    }
  }
}




