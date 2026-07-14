import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String type; // "verification_completed"
  final String reportId;
  final DateTime createdAt;
  final bool isRead;
  final double score;
  final String prediction; // "REAL" or "FAKE"
  final String videoName;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.reportId,
    required this.createdAt,
    required this.isRead,
    required this.score,
    required this.prediction,
    required this.videoName,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'verification_completed',
      reportId: map['reportId'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      score: (map['score'] ?? 0.0).toDouble(),
      prediction: map['prediction'] ?? 'REAL',
      videoName: map['videoName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'reportId': reportId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'score': score,
      'prediction': prediction,
      'videoName': videoName,
    };
  }
}
