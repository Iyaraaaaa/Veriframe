import 'package:flutter/material.dart';
import 'package:veriframe_app/screens/verify.dart';

class MediaModalitySelectionPage extends StatefulWidget {
  const MediaModalitySelectionPage({super.key, this.asModal = false});

  /// Allows opening this exact design as a bottom sheet modal as well
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (context) => const MediaModalitySelectionPage(asModal: true),
    );
  }

  final bool asModal;
  const MediaModalitySelectionPage.asModal({super.key}) : asModal = true;

  @override
  State<MediaModalitySelectionPage> createState() =>
      _MediaModalitySelectionPageState();
}

class _MediaModalitySelectionPageState
    extends State<MediaModalitySelectionPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.asModal) {
      return _buildSheetContent(context, isDark);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF091B3A),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar matching the reference mockup
            _buildTopAppBar(context),

            // White rounded sheet container matching reference
            Expanded(
              child: _buildSheetContent(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF6B87B2), size: 24),
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'VERIFRAME',
                    style: TextStyle(
                      color: Color(0xFF5B7EA6),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Notification Bell with Orange '1' Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, color: Color(0xFF6B87B2), size: 22),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE04F38),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              const Icon(Icons.language_rounded, color: Color(0xFF6B87B2), size: 20),
              const SizedBox(width: 16),
              const Icon(Icons.dark_mode_outlined, color: Color(0xFF6B87B2), size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContent(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0D1B2A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pill Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header Top Row: AI ENSEMBLE pill & Close button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4158D0), Color(0xFF7E57C2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4158D0).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'AI ENSEMBLE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: subtitleColor,
                      size: 22,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Title & Subtitle
              Text(
                'Select Media Modality',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose what type of content you want to inspect for deepfakes and AI generation.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // 1. Video Verification Card
              _ModalityCard(
                iconWidget: const Icon(Icons.videocam_rounded, color: Colors.white, size: 26),
                iconGradient: const [Color(0xFF2B70F6), Color(0xFF1D4ED8)],
                iconShadowColor: const Color(0xFF2563EB),
                badgeText: 'Video & Stream',
                badgeBgColor: const Color(0xFFE0F0FE),
                badgeTextColor: const Color(0xFF1D72D6),
                title: 'Video Verification',
                description: 'Local video upload, YouTube/web links, and live camera stream',
                tags: const ['Local Video', 'Video Link', 'Live Stream'],
                onTap: () {
                  if (widget.asModal) Navigator.pop(context);
                  Navigator.pushNamed(context, '/analyze');
                },
                onTagTap: (tag) {
                  if (widget.asModal) Navigator.pop(context);
                  if (tag == 'Live Stream') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VerifyPage(initialStreamUrl: ''),
                      ),
                    );
                  } else if (tag == 'Video Link') {
                    Navigator.pushNamed(context, '/video_link');
                  } else {
                    Navigator.pushNamed(context, '/analyze');
                  }
                },
              ),
              const SizedBox(height: 14),

              // 2. Image Verification Card
              _ModalityCard(
                iconWidget: const Icon(Icons.image_search_rounded, color: Colors.white, size: 25),
                iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
                iconShadowColor: const Color(0xFF10B981),
                badgeText: 'Image & URL',
                badgeBgColor: const Color(0xFFD8F7E8),
                badgeTextColor: const Color(0xFF0E8C56),
                title: 'Image Verification',
                description: 'Detect diffusion artifacts, face swaps, GAN photos & web image links',
                tags: const ['Local Photo', 'Image Link', 'FFT Grid'],
                onTap: () {
                  if (widget.asModal) Navigator.pop(context);
                  Navigator.pushNamed(context, '/image');
                },
                onTagTap: (tag) {
                  if (widget.asModal) Navigator.pop(context);
                  Navigator.pushNamed(context, '/image');
                },
              ),
              const SizedBox(height: 14),

              // 3. Audio Voice Verification Card
              _ModalityCard(
                iconWidget: _buildAudioWaveIcon(),
                iconGradient: const [Color(0xFFF97316), Color(0xFFEA580C)],
                iconShadowColor: const Color(0xFFEA580C),
                badgeText: 'Voice Clone AI',
                badgeBgColor: const Color(0xFFFEECD6),
                badgeTextColor: const Color(0xFFB85A08),
                title: 'Audio Voice Verification',
                description: 'Identify cloned voices, ElevenLabs speech synthesis & vocoder artifacts',
                tags: const ['Local Audio', 'Voice Cloning', 'Acoustic Forensics'],
                onTap: () {
                  if (widget.asModal) Navigator.pop(context);
                  Navigator.pushNamed(context, '/audio');
                },
                onTagTap: (tag) {
                  if (widget.asModal) Navigator.pop(context);
                  Navigator.pushNamed(context, '/audio');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildAudioWaveIcon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(width: 3, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 2.5),
        Container(width: 3, height: 18, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 2.5),
        Container(width: 3, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 2.5),
        Container(width: 3, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 2.5),
        Container(width: 3, height: 8, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
      ],
    );
  }
}

class _ModalityCard extends StatelessWidget {
  final Widget iconWidget;
  final List<Color> iconGradient;
  final Color iconShadowColor;
  final String badgeText;
  final Color badgeBgColor;
  final Color badgeTextColor;
  final String title;
  final String description;
  final List<String> tags;
  final VoidCallback onTap;
  final void Function(String tag)? onTagTap;

  const _ModalityCard({
    required this.iconWidget,
    required this.iconGradient,
    required this.iconShadowColor,
    required this.badgeText,
    required this.badgeBgColor,
    required this.badgeTextColor,
    required this.title,
    required this.description,
    required this.tags,
    required this.onTap,
    this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF131D2E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final descColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final tagBg = isDark ? const Color(0xFF0B1424) : Colors.white;
    final tagBorder = isDark ? const Color(0xFF26354D) : const Color(0xFFD0D7E2);
    final tagTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder, width: 1.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Squircle Icon Container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: iconShadowColor.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(child: iconWidget),
              ),
              const SizedBox(width: 14),

              // Content Area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top line: Title & Badge on left, Chevron on right
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                  letterSpacing: -0.2,
                                  height: 1.25,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? badgeBgColor.withValues(alpha: 0.18)
                                      : badgeBgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    color: isDark ? badgeBgColor : badgeTextColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Description Text
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: descColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Interactive Action Tag Buttons
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: tags.map((tag) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (onTagTap != null) {
                                onTagTap!(tag);
                              } else {
                                onTap();
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4.5,
                              ),
                              decoration: BoxDecoration(
                                color: tagBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: tagBorder,
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: tagTextColor,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
