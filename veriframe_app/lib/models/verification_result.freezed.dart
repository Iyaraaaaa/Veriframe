// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'verification_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

VerificationResult _$VerificationResultFromJson(Map<String, dynamic> json) {
  return _VerificationResult.fromJson(json);
}

/// @nodoc
mixin _$VerificationResult {
  String get verificationId => throw _privateConstructorUsedError;
  DateTime get verifiedAt => throw _privateConstructorUsedError;
  String get mediaType => throw _privateConstructorUsedError;
  String get source => throw _privateConstructorUsedError;
  double get authenticityScore => throw _privateConstructorUsedError;
  double get fakeProbability => throw _privateConstructorUsedError;
  double get confidence => throw _privateConstructorUsedError;
  double get metadataScore => throw _privateConstructorUsedError;
  double get frameConsistency => throw _privateConstructorUsedError;
  double get ocrConfidence => throw _privateConstructorUsedError;
  double get trackingConfidence => throw _privateConstructorUsedError;
  double get manipulationScore => throw _privateConstructorUsedError;
  String get verdict => throw _privateConstructorUsedError;
  String get riskLevel => throw _privateConstructorUsedError;
  List<String> get detectedEvidence => throw _privateConstructorUsedError;
  List<String> get forensicObservations => throw _privateConstructorUsedError;
  String get reportHash =>
      throw _privateConstructorUsedError; // UI metadata helper fields
  String? get mediaName => throw _privateConstructorUsedError;
  String? get mediaPath => throw _privateConstructorUsedError;
  String? get pdfPath => throw _privateConstructorUsedError;
  String? get thumbnailBase64 => throw _privateConstructorUsedError;

  /// Serializes this VerificationResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VerificationResultCopyWith<VerificationResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VerificationResultCopyWith<$Res> {
  factory $VerificationResultCopyWith(
    VerificationResult value,
    $Res Function(VerificationResult) then,
  ) = _$VerificationResultCopyWithImpl<$Res, VerificationResult>;
  @useResult
  $Res call({
    String verificationId,
    DateTime verifiedAt,
    String mediaType,
    String source,
    double authenticityScore,
    double fakeProbability,
    double confidence,
    double metadataScore,
    double frameConsistency,
    double ocrConfidence,
    double trackingConfidence,
    double manipulationScore,
    String verdict,
    String riskLevel,
    List<String> detectedEvidence,
    List<String> forensicObservations,
    String reportHash,
    String? mediaName,
    String? mediaPath,
    String? pdfPath,
    String? thumbnailBase64,
  });
}

/// @nodoc
class _$VerificationResultCopyWithImpl<$Res, $Val extends VerificationResult>
    implements $VerificationResultCopyWith<$Res> {
  _$VerificationResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? verificationId = null,
    Object? verifiedAt = null,
    Object? mediaType = null,
    Object? source = null,
    Object? authenticityScore = null,
    Object? fakeProbability = null,
    Object? confidence = null,
    Object? metadataScore = null,
    Object? frameConsistency = null,
    Object? ocrConfidence = null,
    Object? trackingConfidence = null,
    Object? manipulationScore = null,
    Object? verdict = null,
    Object? riskLevel = null,
    Object? detectedEvidence = null,
    Object? forensicObservations = null,
    Object? reportHash = null,
    Object? mediaName = freezed,
    Object? mediaPath = freezed,
    Object? pdfPath = freezed,
    Object? thumbnailBase64 = freezed,
  }) {
    return _then(
      _value.copyWith(
            verificationId: null == verificationId
                ? _value.verificationId
                : verificationId // ignore: cast_nullable_to_non_nullable
                      as String,
            verifiedAt: null == verifiedAt
                ? _value.verifiedAt
                : verifiedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            mediaType: null == mediaType
                ? _value.mediaType
                : mediaType // ignore: cast_nullable_to_non_nullable
                      as String,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as String,
            authenticityScore: null == authenticityScore
                ? _value.authenticityScore
                : authenticityScore // ignore: cast_nullable_to_non_nullable
                      as double,
            fakeProbability: null == fakeProbability
                ? _value.fakeProbability
                : fakeProbability // ignore: cast_nullable_to_non_nullable
                      as double,
            confidence: null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                      as double,
            metadataScore: null == metadataScore
                ? _value.metadataScore
                : metadataScore // ignore: cast_nullable_to_non_nullable
                      as double,
            frameConsistency: null == frameConsistency
                ? _value.frameConsistency
                : frameConsistency // ignore: cast_nullable_to_non_nullable
                      as double,
            ocrConfidence: null == ocrConfidence
                ? _value.ocrConfidence
                : ocrConfidence // ignore: cast_nullable_to_non_nullable
                      as double,
            trackingConfidence: null == trackingConfidence
                ? _value.trackingConfidence
                : trackingConfidence // ignore: cast_nullable_to_non_nullable
                      as double,
            manipulationScore: null == manipulationScore
                ? _value.manipulationScore
                : manipulationScore // ignore: cast_nullable_to_non_nullable
                      as double,
            verdict: null == verdict
                ? _value.verdict
                : verdict // ignore: cast_nullable_to_non_nullable
                      as String,
            riskLevel: null == riskLevel
                ? _value.riskLevel
                : riskLevel // ignore: cast_nullable_to_non_nullable
                      as String,
            detectedEvidence: null == detectedEvidence
                ? _value.detectedEvidence
                : detectedEvidence // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            forensicObservations: null == forensicObservations
                ? _value.forensicObservations
                : forensicObservations // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            reportHash: null == reportHash
                ? _value.reportHash
                : reportHash // ignore: cast_nullable_to_non_nullable
                      as String,
            mediaName: freezed == mediaName
                ? _value.mediaName
                : mediaName // ignore: cast_nullable_to_non_nullable
                      as String?,
            mediaPath: freezed == mediaPath
                ? _value.mediaPath
                : mediaPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            pdfPath: freezed == pdfPath
                ? _value.pdfPath
                : pdfPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            thumbnailBase64: freezed == thumbnailBase64
                ? _value.thumbnailBase64
                : thumbnailBase64 // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$VerificationResultImplCopyWith<$Res>
    implements $VerificationResultCopyWith<$Res> {
  factory _$$VerificationResultImplCopyWith(
    _$VerificationResultImpl value,
    $Res Function(_$VerificationResultImpl) then,
  ) = __$$VerificationResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String verificationId,
    DateTime verifiedAt,
    String mediaType,
    String source,
    double authenticityScore,
    double fakeProbability,
    double confidence,
    double metadataScore,
    double frameConsistency,
    double ocrConfidence,
    double trackingConfidence,
    double manipulationScore,
    String verdict,
    String riskLevel,
    List<String> detectedEvidence,
    List<String> forensicObservations,
    String reportHash,
    String? mediaName,
    String? mediaPath,
    String? pdfPath,
    String? thumbnailBase64,
  });
}

/// @nodoc
class __$$VerificationResultImplCopyWithImpl<$Res>
    extends _$VerificationResultCopyWithImpl<$Res, _$VerificationResultImpl>
    implements _$$VerificationResultImplCopyWith<$Res> {
  __$$VerificationResultImplCopyWithImpl(
    _$VerificationResultImpl _value,
    $Res Function(_$VerificationResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of VerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? verificationId = null,
    Object? verifiedAt = null,
    Object? mediaType = null,
    Object? source = null,
    Object? authenticityScore = null,
    Object? fakeProbability = null,
    Object? confidence = null,
    Object? metadataScore = null,
    Object? frameConsistency = null,
    Object? ocrConfidence = null,
    Object? trackingConfidence = null,
    Object? manipulationScore = null,
    Object? verdict = null,
    Object? riskLevel = null,
    Object? detectedEvidence = null,
    Object? forensicObservations = null,
    Object? reportHash = null,
    Object? mediaName = freezed,
    Object? mediaPath = freezed,
    Object? pdfPath = freezed,
    Object? thumbnailBase64 = freezed,
  }) {
    return _then(
      _$VerificationResultImpl(
        verificationId: null == verificationId
            ? _value.verificationId
            : verificationId // ignore: cast_nullable_to_non_nullable
                  as String,
        verifiedAt: null == verifiedAt
            ? _value.verifiedAt
            : verifiedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        mediaType: null == mediaType
            ? _value.mediaType
            : mediaType // ignore: cast_nullable_to_non_nullable
                  as String,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        authenticityScore: null == authenticityScore
            ? _value.authenticityScore
            : authenticityScore // ignore: cast_nullable_to_non_nullable
                  as double,
        fakeProbability: null == fakeProbability
            ? _value.fakeProbability
            : fakeProbability // ignore: cast_nullable_to_non_nullable
                  as double,
        confidence: null == confidence
            ? _value.confidence
            : confidence // ignore: cast_nullable_to_non_nullable
                  as double,
        metadataScore: null == metadataScore
            ? _value.metadataScore
            : metadataScore // ignore: cast_nullable_to_non_nullable
                  as double,
        frameConsistency: null == frameConsistency
            ? _value.frameConsistency
            : frameConsistency // ignore: cast_nullable_to_non_nullable
                  as double,
        ocrConfidence: null == ocrConfidence
            ? _value.ocrConfidence
            : ocrConfidence // ignore: cast_nullable_to_non_nullable
                  as double,
        trackingConfidence: null == trackingConfidence
            ? _value.trackingConfidence
            : trackingConfidence // ignore: cast_nullable_to_non_nullable
                  as double,
        manipulationScore: null == manipulationScore
            ? _value.manipulationScore
            : manipulationScore // ignore: cast_nullable_to_non_nullable
                  as double,
        verdict: null == verdict
            ? _value.verdict
            : verdict // ignore: cast_nullable_to_non_nullable
                  as String,
        riskLevel: null == riskLevel
            ? _value.riskLevel
            : riskLevel // ignore: cast_nullable_to_non_nullable
                  as String,
        detectedEvidence: null == detectedEvidence
            ? _value._detectedEvidence
            : detectedEvidence // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        forensicObservations: null == forensicObservations
            ? _value._forensicObservations
            : forensicObservations // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        reportHash: null == reportHash
            ? _value.reportHash
            : reportHash // ignore: cast_nullable_to_non_nullable
                  as String,
        mediaName: freezed == mediaName
            ? _value.mediaName
            : mediaName // ignore: cast_nullable_to_non_nullable
                  as String?,
        mediaPath: freezed == mediaPath
            ? _value.mediaPath
            : mediaPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        pdfPath: freezed == pdfPath
            ? _value.pdfPath
            : pdfPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        thumbnailBase64: freezed == thumbnailBase64
            ? _value.thumbnailBase64
            : thumbnailBase64 // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$VerificationResultImpl implements _VerificationResult {
  const _$VerificationResultImpl({
    required this.verificationId,
    required this.verifiedAt,
    required this.mediaType,
    required this.source,
    required this.authenticityScore,
    required this.fakeProbability,
    required this.confidence,
    required this.metadataScore,
    required this.frameConsistency,
    required this.ocrConfidence,
    required this.trackingConfidence,
    required this.manipulationScore,
    required this.verdict,
    required this.riskLevel,
    required final List<String> detectedEvidence,
    required final List<String> forensicObservations,
    required this.reportHash,
    this.mediaName,
    this.mediaPath,
    this.pdfPath,
    this.thumbnailBase64,
  }) : _detectedEvidence = detectedEvidence,
       _forensicObservations = forensicObservations;

  factory _$VerificationResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$VerificationResultImplFromJson(json);

  @override
  final String verificationId;
  @override
  final DateTime verifiedAt;
  @override
  final String mediaType;
  @override
  final String source;
  @override
  final double authenticityScore;
  @override
  final double fakeProbability;
  @override
  final double confidence;
  @override
  final double metadataScore;
  @override
  final double frameConsistency;
  @override
  final double ocrConfidence;
  @override
  final double trackingConfidence;
  @override
  final double manipulationScore;
  @override
  final String verdict;
  @override
  final String riskLevel;
  final List<String> _detectedEvidence;
  @override
  List<String> get detectedEvidence {
    if (_detectedEvidence is EqualUnmodifiableListView)
      return _detectedEvidence;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_detectedEvidence);
  }

  final List<String> _forensicObservations;
  @override
  List<String> get forensicObservations {
    if (_forensicObservations is EqualUnmodifiableListView)
      return _forensicObservations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_forensicObservations);
  }

  @override
  final String reportHash;
  // UI metadata helper fields
  @override
  final String? mediaName;
  @override
  final String? mediaPath;
  @override
  final String? pdfPath;
  @override
  final String? thumbnailBase64;

  @override
  String toString() {
    return 'VerificationResult(verificationId: $verificationId, verifiedAt: $verifiedAt, mediaType: $mediaType, source: $source, authenticityScore: $authenticityScore, fakeProbability: $fakeProbability, confidence: $confidence, metadataScore: $metadataScore, frameConsistency: $frameConsistency, ocrConfidence: $ocrConfidence, trackingConfidence: $trackingConfidence, manipulationScore: $manipulationScore, verdict: $verdict, riskLevel: $riskLevel, detectedEvidence: $detectedEvidence, forensicObservations: $forensicObservations, reportHash: $reportHash, mediaName: $mediaName, mediaPath: $mediaPath, pdfPath: $pdfPath, thumbnailBase64: $thumbnailBase64)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VerificationResultImpl &&
            (identical(other.verificationId, verificationId) ||
                other.verificationId == verificationId) &&
            (identical(other.verifiedAt, verifiedAt) ||
                other.verifiedAt == verifiedAt) &&
            (identical(other.mediaType, mediaType) ||
                other.mediaType == mediaType) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.authenticityScore, authenticityScore) ||
                other.authenticityScore == authenticityScore) &&
            (identical(other.fakeProbability, fakeProbability) ||
                other.fakeProbability == fakeProbability) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.metadataScore, metadataScore) ||
                other.metadataScore == metadataScore) &&
            (identical(other.frameConsistency, frameConsistency) ||
                other.frameConsistency == frameConsistency) &&
            (identical(other.ocrConfidence, ocrConfidence) ||
                other.ocrConfidence == ocrConfidence) &&
            (identical(other.trackingConfidence, trackingConfidence) ||
                other.trackingConfidence == trackingConfidence) &&
            (identical(other.manipulationScore, manipulationScore) ||
                other.manipulationScore == manipulationScore) &&
            (identical(other.verdict, verdict) || other.verdict == verdict) &&
            (identical(other.riskLevel, riskLevel) ||
                other.riskLevel == riskLevel) &&
            const DeepCollectionEquality().equals(
              other._detectedEvidence,
              _detectedEvidence,
            ) &&
            const DeepCollectionEquality().equals(
              other._forensicObservations,
              _forensicObservations,
            ) &&
            (identical(other.reportHash, reportHash) ||
                other.reportHash == reportHash) &&
            (identical(other.mediaName, mediaName) ||
                other.mediaName == mediaName) &&
            (identical(other.mediaPath, mediaPath) ||
                other.mediaPath == mediaPath) &&
            (identical(other.pdfPath, pdfPath) || other.pdfPath == pdfPath) &&
            (identical(other.thumbnailBase64, thumbnailBase64) ||
                other.thumbnailBase64 == thumbnailBase64));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    verificationId,
    verifiedAt,
    mediaType,
    source,
    authenticityScore,
    fakeProbability,
    confidence,
    metadataScore,
    frameConsistency,
    ocrConfidence,
    trackingConfidence,
    manipulationScore,
    verdict,
    riskLevel,
    const DeepCollectionEquality().hash(_detectedEvidence),
    const DeepCollectionEquality().hash(_forensicObservations),
    reportHash,
    mediaName,
    mediaPath,
    pdfPath,
    thumbnailBase64,
  ]);

  /// Create a copy of VerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VerificationResultImplCopyWith<_$VerificationResultImpl> get copyWith =>
      __$$VerificationResultImplCopyWithImpl<_$VerificationResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$VerificationResultImplToJson(this);
  }
}

abstract class _VerificationResult implements VerificationResult {
  const factory _VerificationResult({
    required final String verificationId,
    required final DateTime verifiedAt,
    required final String mediaType,
    required final String source,
    required final double authenticityScore,
    required final double fakeProbability,
    required final double confidence,
    required final double metadataScore,
    required final double frameConsistency,
    required final double ocrConfidence,
    required final double trackingConfidence,
    required final double manipulationScore,
    required final String verdict,
    required final String riskLevel,
    required final List<String> detectedEvidence,
    required final List<String> forensicObservations,
    required final String reportHash,
    final String? mediaName,
    final String? mediaPath,
    final String? pdfPath,
    final String? thumbnailBase64,
  }) = _$VerificationResultImpl;

  factory _VerificationResult.fromJson(Map<String, dynamic> json) =
      _$VerificationResultImpl.fromJson;

  @override
  String get verificationId;
  @override
  DateTime get verifiedAt;
  @override
  String get mediaType;
  @override
  String get source;
  @override
  double get authenticityScore;
  @override
  double get fakeProbability;
  @override
  double get confidence;
  @override
  double get metadataScore;
  @override
  double get frameConsistency;
  @override
  double get ocrConfidence;
  @override
  double get trackingConfidence;
  @override
  double get manipulationScore;
  @override
  String get verdict;
  @override
  String get riskLevel;
  @override
  List<String> get detectedEvidence;
  @override
  List<String> get forensicObservations;
  @override
  String get reportHash; // UI metadata helper fields
  @override
  String? get mediaName;
  @override
  String? get mediaPath;
  @override
  String? get pdfPath;
  @override
  String? get thumbnailBase64;

  /// Create a copy of VerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VerificationResultImplCopyWith<_$VerificationResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
