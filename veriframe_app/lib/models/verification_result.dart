import 'package:freezed_annotation/freezed_annotation.dart';

part 'verification_result.freezed.dart';
part 'verification_result.g.dart';

@freezed
class VerificationResult with _$VerificationResult {
  const factory VerificationResult({
    required String verificationId,
    required DateTime verifiedAt,
    required String mediaType,
    required String source,
    required double authenticityScore,
    required double fakeProbability,
    required double confidence,
    required double metadataScore,
    required double frameConsistency,
    required double ocrConfidence,
    required double trackingConfidence,
    required double manipulationScore,
    required String verdict,
    required String riskLevel,
    required List<String> detectedEvidence,
    required List<String> forensicObservations,
    required String reportHash,
    // UI metadata helper fields
    String? mediaName,
    String? mediaPath,
    String? pdfPath,
    String? thumbnailBase64,
  }) = _VerificationResult;

  factory VerificationResult.fromJson(Map<String, dynamic> json) =>
      _$VerificationResultFromJson(json);
}
