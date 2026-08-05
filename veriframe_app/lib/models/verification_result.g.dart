// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verification_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VerificationResultImpl _$$VerificationResultImplFromJson(
  Map<String, dynamic> json,
) => _$VerificationResultImpl(
  verificationId: json['verificationId'] as String,
  verifiedAt: DateTime.parse(json['verifiedAt'] as String),
  mediaType: json['mediaType'] as String,
  source: json['source'] as String,
  authenticityScore: (json['authenticityScore'] as num).toDouble(),
  fakeProbability: (json['fakeProbability'] as num).toDouble(),
  confidence: (json['confidence'] as num).toDouble(),
  metadataScore: (json['metadataScore'] as num).toDouble(),
  frameConsistency: (json['frameConsistency'] as num).toDouble(),
  ocrConfidence: (json['ocrConfidence'] as num).toDouble(),
  trackingConfidence: (json['trackingConfidence'] as num).toDouble(),
  manipulationScore: (json['manipulationScore'] as num).toDouble(),
  verdict: json['verdict'] as String,
  riskLevel: json['riskLevel'] as String,
  detectedEvidence: (json['detectedEvidence'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  forensicObservations: (json['forensicObservations'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  reportHash: json['reportHash'] as String,
  mediaName: json['mediaName'] as String?,
  mediaPath: json['mediaPath'] as String?,
  pdfPath: json['pdfPath'] as String?,
  thumbnailBase64: json['thumbnailBase64'] as String?,
  videoUrl: json['videoUrl'] as String?,
  platform: json['platform'] as String?,
  videoLength: json['videoLength'] as String?,
  resolution: json['resolution'] as String?,
  framesAnalysedCount: (json['framesAnalysedCount'] as num?)?.toInt(),
  suspiciousFramesCount: (json['suspiciousFramesCount'] as num?)?.toInt(),
  faceDetectionRate: (json['faceDetectionRate'] as num?)?.toDouble(),
  processingTimeSec: (json['processingTimeSec'] as num?)?.toDouble(),
  suspiciousFrames: (json['suspiciousFrames'] as List<dynamic>?)
      ?.map((e) => e as Map<String, dynamic>)
      .toList(),
  timelineLogs: (json['timelineLogs'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$$VerificationResultImplToJson(
  _$VerificationResultImpl instance,
) => <String, dynamic>{
  'verificationId': instance.verificationId,
  'verifiedAt': instance.verifiedAt.toIso8601String(),
  'mediaType': instance.mediaType,
  'source': instance.source,
  'authenticityScore': instance.authenticityScore,
  'fakeProbability': instance.fakeProbability,
  'confidence': instance.confidence,
  'metadataScore': instance.metadataScore,
  'frameConsistency': instance.frameConsistency,
  'ocrConfidence': instance.ocrConfidence,
  'trackingConfidence': instance.trackingConfidence,
  'manipulationScore': instance.manipulationScore,
  'verdict': instance.verdict,
  'riskLevel': instance.riskLevel,
  'detectedEvidence': instance.detectedEvidence,
  'forensicObservations': instance.forensicObservations,
  'reportHash': instance.reportHash,
  'mediaName': instance.mediaName,
  'mediaPath': instance.mediaPath,
  'pdfPath': instance.pdfPath,
  'thumbnailBase64': instance.thumbnailBase64,
  'videoUrl': instance.videoUrl,
  'platform': instance.platform,
  'videoLength': instance.videoLength,
  'resolution': instance.resolution,
  'framesAnalysedCount': instance.framesAnalysedCount,
  'suspiciousFramesCount': instance.suspiciousFramesCount,
  'faceDetectionRate': instance.faceDetectionRate,
  'processingTimeSec': instance.processingTimeSec,
  'suspiciousFrames': instance.suspiciousFrames,
  'timelineLogs': instance.timelineLogs,
};
