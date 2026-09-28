import 'package:flutter/material.dart';
import 'package:veriframe_app/screens/download_analysis_page.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class VideoLinkVerificationPage extends StatefulWidget {
  const VideoLinkVerificationPage({super.key});

  @override
  State<VideoLinkVerificationPage> createState() =>
      _VideoLinkVerificationPageState();
}

class _VideoLinkVerificationPageState extends State<VideoLinkVerificationPage> {
  String selectedPlatform = 'Instagram';
  final TextEditingController linkController = TextEditingController();

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }

  void _selectPlatform(String platform) {
    setState(() {
      selectedPlatform = platform;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131D2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return MainScaffold(
      backgroundColor: isDark ? const Color(0xFF0B1424) : const Color(0xFFF8FAFC),
      showBack: true,
      title: const Text(
        'Link Verification',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // Main White Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & Subtitle Header
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Select Platform',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose where your video is hosted',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: subtitleColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 2x2 Platform Grid
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.15,
                    children: [
                      _buildPlatformCard(
                        name: 'YouTube',
                        icon: Icons.play_arrow_rounded,
                        brandColor: const Color(0xFFFF0000),
                        isDark: isDark,
                        customIconWidget: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF0000).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      _buildPlatformCard(
                        name: 'Instagram',
                        icon: Icons.camera_alt_rounded,
                        brandColor: const Color(0xFFE1306C),
                        isDark: isDark,
                        customIconWidget: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF58529),
                                Color(0xFFDD2A7B),
                                Color(0xFF8134AF),
                              ],
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                            ),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDD2A7B).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      _buildPlatformCard(
                        name: 'Facebook',
                        icon: Icons.facebook_rounded,
                        brandColor: const Color(0xFF1877F2),
                        isDark: isDark,
                        customIconWidget: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1877F2).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'f',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'sans-serif',
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildPlatformCard(
                        name: 'TikTok',
                        icon: Icons.music_note_rounded,
                        brandColor: Colors.black,
                        isDark: isDark,
                        customIconWidget: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: const [
                              Positioned(
                                left: 13,
                                top: 11,
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFF00F2FE),
                                  size: 22,
                                ),
                              ),
                              Positioned(
                                right: 13,
                                bottom: 11,
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFFFE2C55),
                                  size: 22,
                                ),
                              ),
                              Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // VIDEO LINK Label & TextField
                  Text(
                    'VIDEO LINK',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: subtitleColor,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                        width: 1.3,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        // Soft Lavender Chain Link Icon
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.link_rounded,
                            color: Color(0xFF8B5CF6),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: linkController,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: titleColor,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              hintText: 'Paste your video link here...',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // VERIFY NOW Button (Solid Emerald Green with Shield)
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final url = linkController.text.trim();
                        if (url.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please paste a video link first.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DownloadAnalysisPage(videoUrl: url),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gradient Shield Icon
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF38BDF8),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'VERIFY NOW',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformCard({
    required String name,
    required IconData icon,
    required Color brandColor,
    required bool isDark,
    required Widget customIconWidget,
  }) {
    final isSelected = selectedPlatform == name;
    final cardBg = isDark
        ? (isSelected ? const Color(0xFF1E293B) : const Color(0xFF111C2E))
        : (isSelected ? const Color(0xFFF0F9FF) : Colors.white);

    // Selected border color: Uses Instagram pink for Instagram, cyan/brand for others
    final activeBorderColor = name == 'Instagram'
        ? const Color(0xFFE1306C)
        : (name == 'YouTube'
            ? const Color(0xFFFF0000)
            : (name == 'Facebook' ? const Color(0xFF1877F2) : const Color(0xFF0F172A)));

    final cardBorder = isSelected
        ? activeBorderColor
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectPlatform(name),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cardBorder,
              width: isSelected ? 1.8 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeBorderColor.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              customIconWidget,
              const SizedBox(height: 10),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
