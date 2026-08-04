import 'package:flutter/material.dart';

class QualitativeConfidence {
  final String label;
  final String description;
  final Color primaryColor;
  final List<Color> gradientColors;
  final double scorePercent;

  const QualitativeConfidence({
    required this.label,
    required this.description,
    required this.primaryColor,
    required this.gradientColors,
    required this.scorePercent,
  });

  static QualitativeConfidence fromScore(double scorePercent) {
    final score = scorePercent.clamp(0.0, 100.0);
    if (score >= 90.0) {
      return QualitativeConfidence(
        label: 'Very High Confidence',
        description: 'Strong mathematical and spatial feature correlation.',
        primaryColor: const Color(0xFF10B981), // Emerald
        gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
        scorePercent: score,
      );
    } else if (score >= 75.0) {
      return QualitativeConfidence(
        label: 'High Confidence',
        description: 'Consistent evidence across frame analysis.',
        primaryColor: const Color(0xFF06B6D4), // Cyan/Teal
        gradientColors: const [Color(0xFF0891B2), Color(0xFF06B6D4)],
        scorePercent: score,
      );
    } else if (score >= 50.0) {
      return QualitativeConfidence(
        label: 'Moderate Confidence',
        description: 'Notable indicative patterns detected; verification advised.',
        primaryColor: const Color(0xFFF59E0B), // Amber
        gradientColors: const [Color(0xFFD97706), Color(0xFFF59E0B)],
        scorePercent: score,
      );
    } else if (score >= 25.0) {
      return QualitativeConfidence(
        label: 'Low Confidence',
        description: 'Inconclusive signals or high noise/compression artifacts.',
        primaryColor: const Color(0xFFF97316), // Orange
        gradientColors: const [Color(0xFFEA580C), Color(0xFFF97316)],
        scorePercent: score,
      );
    } else {
      return QualitativeConfidence(
        label: 'Very Low Confidence',
        description: 'Weak correlation; source media verification required.',
        primaryColor: const Color(0xFFEF4444), // Rose/Red
        gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
        scorePercent: score,
      );
    }
  }
}

class QualitativeConfidenceBadge extends StatelessWidget {
  final double scorePercent;
  final bool isAuthentic;

  const QualitativeConfidenceBadge({
    super.key,
    required this.scorePercent,
    required this.isAuthentic,
  });

  @override
  Widget build(BuildContext context) {
    final conf = QualitativeConfidence.fromScore(scorePercent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: conf.gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: conf.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            conf.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
