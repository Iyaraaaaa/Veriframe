import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String reportId;
  final String videoName;
  final String videoPath;
  final String prediction; // "REAL" or "FAKE"
  final double confidence;
  final double score;
  final String reasoning;
  final DateTime createdAt;
  final String pdfPath;
  final String pdfName;
  final String thumbnail; // base64 representation of a thumbnail
  final double duration;
  final double processingTime;

  ReportModel({
    required this.reportId,
    required this.videoName,
    required this.videoPath,
    required this.prediction,
    required this.confidence,
    required this.score,
    required this.reasoning,
    required this.createdAt,
    required this.pdfPath,
    required this.pdfName,
    required this.thumbnail,
    required this.duration,
    required this.processingTime,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    return ReportModel(
      reportId: id,
      videoName: map['videoName'] ?? '',
      videoPath: map['videoPath'] ?? '',
      prediction: map['prediction'] ?? 'REAL',
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      score: (map['score'] ?? 0.0).toDouble(),
      reasoning: map['reasoning'] ?? '',
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      pdfPath: map['pdfPath'] ?? '',
      pdfName: map['pdfName'] ?? '',
      thumbnail: map['thumbnail'] ?? '',
      duration: (map['duration'] ?? 0.0).toDouble(),
      processingTime: (map['processingTime'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'videoName': videoName,
      'videoPath': videoPath,
      'prediction': prediction,
      'confidence': confidence,
      'score': score,
      'reasoning': reasoning,
      'createdAt': Timestamp.fromDate(createdAt),
      'pdfPath': pdfPath,
      'pdfName': pdfName,
      'thumbnail': thumbnail,
      'duration': duration,
      'processingTime': processingTime,
    };
  }
}
