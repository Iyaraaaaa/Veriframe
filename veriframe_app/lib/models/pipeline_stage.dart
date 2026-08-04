import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class VerificationStageInfo {
  final int id;
  final String label;
  final String description;
  final IconData icon;

  const VerificationStageInfo({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });
}

const List<VerificationStageInfo> kVerificationStages = [
  VerificationStageInfo(
    id: 0,
    label: 'Media Validation',
    description: 'Validating media headers, SHA-256 hash, and format integrity...',
    icon: Icons.video_file_outlined,
  ),
  VerificationStageInfo(
    id: 1,
    label: 'Metadata Inspection',
    description: 'Analyzing EXIF, container metadata, and timestamp consistency...',
    icon: Icons.troubleshoot_outlined,
  ),
  VerificationStageInfo(
    id: 2,
    label: 'Frame Extraction',
    description: 'Extracting keyframes using adaptive temporal sampling...',
    icon: Icons.movie_creation_outlined,
  ),
  VerificationStageInfo(
    id: 3,
    label: 'Scene Detection',
    description: 'Partitioning video into dynamic visual scenes and cuts...',
    icon: Icons.grid_view_outlined,
  ),
  VerificationStageInfo(
    id: 4,
    label: 'Face Detection',
    description: 'Running RetinaFace / SCRFD face locator cascade...',
    icon: Icons.face_retouching_natural_outlined,
  ),
  VerificationStageInfo(
    id: 5,
    label: 'Face Tracking',
    description: 'Tracking facial bounding boxes across continuous frames...',
    icon: Icons.center_focus_strong_outlined,
  ),
  VerificationStageInfo(
    id: 6,
    label: 'Quality Assessment',
    description: 'Evaluating frame resolution, blur, compression, and lighting...',
    icon: Icons.high_quality_outlined,
  ),
  VerificationStageInfo(
    id: 7,
    label: 'Artifact Detection',
    description: 'Searching for facial boundary glitches and warping artifacts...',
    icon: Icons.saved_search_outlined,
  ),
  VerificationStageInfo(
    id: 8,
    label: 'Deepfake AI Model',
    description: 'Executing EfficientViT TFLite neural inference engine...',
    icon: Icons.psychology_outlined,
  ),
  VerificationStageInfo(
    id: 9,
    label: 'Temporal Consistency',
    description: 'Evaluating frame-to-frame feature persistence and jitter...',
    icon: Icons.timeline_outlined,
  ),
  VerificationStageInfo(
    id: 10,
    label: 'Confidence Calibration',
    description: 'Applying Temperature Scaling (T=1.5) probability smoothing...',
    icon: Icons.tune_outlined,
  ),
  VerificationStageInfo(
    id: 11,
    label: 'Evidence Aggregation',
    description: 'Correlating neural predictions with forensic spatial heuristic data...',
    icon: Icons.query_stats_outlined,
  ),
  VerificationStageInfo(
    id: 12,
    label: 'Risk Scoring',
    description: 'Computing multi-factor threat assessment and risk matrix...',
    icon: Icons.shield_outlined,
  ),
  VerificationStageInfo(
    id: 13,
    label: 'Final Decision',
    description: 'Synthesizing adaptive ensemble verdict...',
    icon: Icons.verified_outlined,
  ),
  VerificationStageInfo(
    id: 14,
    label: 'Generating Report',
    description: 'Assembling complete forensic verification report...',
    icon: Icons.assessment_outlined,
  ),
];

const List<String> kForensicFacts = [
  "EfficientViT evaluates global spatial context with linear computational complexity.",
  "Temperature Scaling (T=1.5) prevents neural network overconfidence in edge cases.",
  "RetinaFace uses multi-scale feature pyramids to detect occluded faces instantly.",
  "Temporal consistency tracking analyzes frame-to-frame micro-blinking dynamics.",
  "VeriFrame cross-references findings against DFDC, FaceForensics++, and Celeb-DF v2 benchmarks.",
];

List<VerificationStageInfo> getLocalizedVerificationStages(BuildContext context) {
  final loc = AppLocalizations.of(context)!;
  return [
    VerificationStageInfo(
      id: 0,
      label: loc.mediaValidationLabel,
      description: loc.mediaValidationDesc,
      icon: Icons.video_file_outlined,
    ),
    VerificationStageInfo(
      id: 1,
      label: loc.metadataInspectionLabel,
      description: loc.metadataInspectionDesc,
      icon: Icons.troubleshoot_outlined,
    ),
    VerificationStageInfo(
      id: 2,
      label: loc.frameExtractionLabel,
      description: loc.frameExtractionDesc,
      icon: Icons.movie_creation_outlined,
    ),
    VerificationStageInfo(
      id: 3,
      label: loc.sceneDetectionLabel,
      description: loc.sceneDetectionDesc,
      icon: Icons.grid_view_outlined,
    ),
    VerificationStageInfo(
      id: 4,
      label: loc.faceDetectionLabel,
      description: loc.faceDetectionDesc,
      icon: Icons.face_retouching_natural_outlined,
    ),
    VerificationStageInfo(
      id: 5,
      label: loc.faceTrackingLabel,
      description: loc.faceTrackingDesc,
      icon: Icons.center_focus_strong_outlined,
    ),
    VerificationStageInfo(
      id: 6,
      label: loc.qualityAssessmentLabel,
      description: loc.qualityAssessmentDesc,
      icon: Icons.high_quality_outlined,
    ),
    VerificationStageInfo(
      id: 7,
      label: loc.artifactDetectionLabel,
      description: loc.artifactDetectionDesc,
      icon: Icons.saved_search_outlined,
    ),
    VerificationStageInfo(
      id: 8,
      label: loc.deepfakeAiModelLabel,
      description: loc.deepfakeAiModelDesc,
      icon: Icons.psychology_outlined,
    ),
    VerificationStageInfo(
      id: 9,
      label: loc.temporalConsistencyLabel,
      description: loc.temporalConsistencyDesc,
      icon: Icons.timeline_outlined,
    ),
    VerificationStageInfo(
      id: 10,
      label: loc.confidenceCalibrationLabel,
      description: loc.confidenceCalibrationDesc,
      icon: Icons.tune_outlined,
    ),
    VerificationStageInfo(
      id: 11,
      label: loc.evidenceAggregationLabel,
      description: loc.evidenceAggregationDesc,
      icon: Icons.query_stats_outlined,
    ),
    VerificationStageInfo(
      id: 12,
      label: loc.riskScoringLabel,
      description: loc.riskScoringDesc,
      icon: Icons.shield_outlined,
    ),
    VerificationStageInfo(
      id: 13,
      label: loc.finalDecisionLabel,
      description: loc.finalDecisionDesc,
      icon: Icons.verified_outlined,
    ),
    VerificationStageInfo(
      id: 14,
      label: loc.generatingReportLabel,
      description: loc.generatingReportDesc,
      icon: Icons.assessment_outlined,
    ),
  ];
}
