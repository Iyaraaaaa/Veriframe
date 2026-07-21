import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class TechnologyStackPage extends StatelessWidget {
  const TechnologyStackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final techItems = [
      _TechItem(
        icon: Icons.flutter_dash_outlined,
        title: 'Flutter',
        description: 'Cross-platform UI framework for building natively compiled applications.',
        color: VFColors.blue600,
      ),
      _TechItem(
        icon: Icons.code_outlined,
        title: 'Dart',
        description: 'Optimized programming language for fast, multi-platform development.',
        color: VFColors.blue700,
      ),
      _TechItem(
        icon: Icons.lock_outline_rounded,
        title: 'Firebase Authentication',
        description: 'Secure user authentication with email, Google Sign-In, and session management.',
        color: VFColors.amber600,
      ),
      _TechItem(
        icon: Icons.storage_outlined,
        title: 'Cloud Firestore',
        description: 'NoSQL cloud database for real-time user data, notifications, and reports.',
        color: VFColors.emerald600,
      ),
      _TechItem(
        icon: Icons.cloud_upload_outlined,
        title: 'Firebase Storage',
        description: 'Scalable object storage for profile images and media assets.',
        color: VFColors.violet600,
      ),
      _TechItem(
        icon: Icons.psychology_outlined,
        title: 'TensorFlow Lite',
        description: 'On-device machine learning for deepfake detection inference.',
        color: VFColors.red600,
      ),
      _TechItem(
        icon: Icons.api_outlined,
        title: 'FastAPI Backend',
        description: 'High-performance Python backend for forensic video analysis APIs.',
        color: VFColors.slate600,
      ),
      _TechItem(
        icon: Icons.data_object_outlined,
        title: 'Python',
        description: 'Backend language powering AI pipelines, model serving, and orchestration.',
        color: VFColors.blue700,
      ),
      _TechItem(
        icon: Icons.face_retouching_natural_outlined,
        title: 'OpenCV',
        description: 'Computer vision library for face detection, cropping, and preprocessing.',
        color: VFColors.violet600,
      ),
      _TechItem(
        icon: Icons.video_settings_outlined,
        title: 'FFmpeg',
        description: 'Multimedia framework for video decoding, frame extraction, and stream processing.',
        color: VFColors.emerald600,
      ),
      _TechItem(
        icon: Icons.auto_awesome_outlined,
        title: 'Deepfake Detection AI Model',
        description: 'EfficientViT and CrossEfficientViT models for forensic authenticity analysis.',
        color: VFColors.blue700,
      ),
      _TechItem(
        icon: Icons.palette_outlined,
        title: 'Material Design',
        description: 'Google design system for consistent, accessible, and beautiful UI components.',
        color: VFColors.amber600,
      ),
    ];

    return MainScaffold(
      showBack: true,
      title: Text(loc.techStackTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? VFColors.navySurface : VFColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? VFColors.gray800 : VFColors.gray200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   children: [
                     Icon(Icons.memory_outlined, size: 18, color: VFColors.blue600),
                     const SizedBox(width: 8),
                     Text(
                       loc.techStackTitle,
                       style: TextStyle(
                         color: isDark ? VFColors.white : VFColors.gray900,
                         fontSize: 16,
                         fontWeight: FontWeight.w800,
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Text(
                   loc.techStackSubtitle,
                   style: TextStyle(
                     color: isDark ? VFColors.slate400 : VFColors.slate600,
                     fontSize: 13,
                     height: 1.5,
                   ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...techItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TechCard(item: item, isDark: isDark),
          )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TechItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _TechItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _TechCard extends StatelessWidget {
  final _TechItem item;
  final bool isDark;

  const _TechCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? VFColors.navySurface : VFColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? VFColors.gray800 : VFColors.gray200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? VFColors.white : VFColors.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? VFColors.slate400 : VFColors.slate600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
