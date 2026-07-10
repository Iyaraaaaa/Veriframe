import 'dart:io';

void main() {
  final file = File(r'D:\VERI_FRAME\veriframe_app\lib\screens\home_page.dart');
  String content = file.readAsStringSync();

  final startHome = content.indexOf('  Widget _buildHomeContent() {');
  final endHome = content.indexOf('  // ══════════════════════════════════════════', startHome + 10);
  
  // We want to replace from the start of _buildHomeContent up to the start of the SCAFFOLD section.
  // Wait, let's just find the start of SCAFFOLD section.
  final endScaffold = content.indexOf('  @override\n  Widget build(BuildContext context) {');
  if (endScaffold == -1) {
    // try CRLF
    final endScaffoldCRLF = content.indexOf('  @override\r\n  Widget build(BuildContext context) {');
    if (endScaffoldCRLF == -1) {
      print('Could not find build method');
      return;
    }
  }

  // Let's use Regex to replace everything from _buildHomeContent to the build method.
  final pattern = RegExp(r'  Widget _buildHomeContent\(\) \{.*?(?=  @override\r?\n  Widget build\(BuildContext context\))', dotAll: true);
  
  if (pattern.hasMatch(content)) {
    String newHomeSection = '''  Widget _buildHomeContent() {
    final isDark = widget.isDarkMode;
    final cardBg = VFColors.adaptiveCard(isDark);
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile row with pencil edit icon ──
          Row(
            children: [
              Stack(
                children: [
                  _getProfileImage(radius: 26),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _openEditProfile,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: VFColors.blue600,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? VFColors.navyMid : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, \${_userName.split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VeriFrame Forensic Detection Platform',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VFColors.emerald600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VFColors.emerald600.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: VFColors.emerald600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: VFColors.emerald600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Hero Section ──
          Center(
            child: Column(
              children: [
                Text(
                  'VeriFrame',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: text,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI-Powered Video Authenticity Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: VFColors.blue600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Detect deepfakes, manipulated videos, and synthetic media using advanced AI analysis and explainable forensic reasoning.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: text,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'VeriFrame analyzes uploaded videos, video links, and live streams using EfficientViT and CrossEfficientViT models to determine whether media is authentic or manipulated.\\n\\nThe platform generates confidence scores, forensic evidence, and detailed reports to support digital trust and cybercrime investigations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── What is VeriFrame? ──
          Text(
            'What is VeriFrame?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
            ),
            child: Text(
              'VeriFrame helps journalists, investigators, organizations, students, and the public identify manipulated videos and potential deepfakes.\\n\\nThe system performs AI-powered forensic analysis and provides transparent explanations of why content is considered authentic or suspicious.',
              style: TextStyle(
                fontSize: 14,
                color: text,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Features Cards ──
          Text(
            'Features',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _buildFeatureCard('Video Verification', 'Analyze uploaded videos using AI.', Icons.video_file, isDark),
              _buildFeatureCard('Link Verification', 'Analyze videos directly from a URL.', Icons.link, isDark),
              _buildFeatureCard('Live Stream Monitoring', 'Detect manipulation in streaming content.', Icons.live_tv, isDark),
              _buildFeatureCard('AI Reasoning', 'Understand why a video was flagged.', Icons.psychology, isDark),
              _buildFeatureCard('Forensic Reports', 'Generate downloadable investigation reports.', Icons.description, isDark),
              _buildFeatureCard('Authority Reporting', 'Submit high-risk cases for review.', Icons.local_police, isDark),
            ],
          ),
          const SizedBox(height: 32),

          // ── How It Works ──
          Text(
            'How It Works',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          _buildNewHowItWorksCard(isDark, cardBg, text, muted),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  VERIFY CONTENT
  // ══════════════════════════════════════════
  Widget _buildVerifyContent() {
    final isDark = widget.isDarkMode;
    final cardBg = VFColors.adaptiveCard(isDark);
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Verify Media',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a verification method to analyze a video for authenticity and potential manipulation.',
            style: TextStyle(
              fontSize: 14,
              color: muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Upload Video Card
          _buildVerifyMethodCard(
            title: 'Upload Video',
            description: 'Upload a video file from your device for AI analysis.',
            icon: Icons.upload_file,
            isDark: isDark,
            cardBg: cardBg,
            text: text,
            muted: muted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supported: MP4, MOV, AVI, MKV',
                  style: TextStyle(fontSize: 12, color: muted, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToAnalyze,
                    icon: const Icon(Icons.video_file),
                    label: const Text('Select Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VFColors.blue600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Analyze Video Link Card
          _buildVerifyMethodCard(
            title: 'Analyze Video Link',
            description: 'Paste a public video URL and let VeriFrame analyze its authenticity.',
            icon: Icons.link,
            isDark: isDark,
            cardBg: cardBg,
            text: text,
            muted: muted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter video URL...',
                    hintStyle: TextStyle(color: muted, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F1523) : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: text, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Examples: YouTube, Facebook, TikTok, Instagram, X',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToAnalyze,
                    icon: const Icon(Icons.search),
                    label: const Text('Analyze Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VFColors.emerald600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Analyze Live Stream Card
          _buildVerifyMethodCard(
            title: 'Analyze Live Stream',
            description: 'Monitor and analyze live streaming content in real time.',
            icon: Icons.live_tv,
            isDark: isDark,
            cardBg: cardBg,
            text: text,
            muted: muted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter stream URL...',
                    hintStyle: TextStyle(color: muted, fontSize: 13),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F1523) : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: text, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported: RTMP, HLS, YouTube Live, Facebook Live',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _navigateToAnalyze,
                    icon: const Icon(Icons.cast),
                    label: const Text('Analyze Stream'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VFColors.amber600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVerifyMethodCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color text,
    required Color muted,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VFColors.blue600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: VFColors.blue600, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, String desc, IconData icon, bool isDark) {
    final cardBg = VFColors.adaptiveCard(isDark);
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VFColors.blue600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: VFColors.blue600, size: 20),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontSize: 11,
              color: muted,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNewHowItWorksCard(bool isDark, Color cardBg, Color text, Color muted) {
    final steps = [
      {'title': 'Upload / Link / Live Stream', 'desc': 'Submit media for analysis via supported methods.'},
      {'title': 'Face Detection', 'desc': 'Identify and crop facial regions across frames.'},
      {'title': 'AI Analysis', 'desc': 'Process frames using EfficientViT & CrossEfficientViT.'},
      {'title': 'Reasoning Engine', 'desc': 'Generate explainable insights on anomalies.'},
      {'title': 'Authenticity Score', 'desc': 'Calculate final confidence and risk level.'},
      {'title': 'Forensic Report', 'desc': 'Compile detailed findings into a downloadable report.'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          int idx = entry.key;
          var s = entry.value;
          bool isLast = idx == steps.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: VFColors.blue600,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_downward, size: 14, color: Colors.white),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: VFColors.blue600.withOpacity(0.3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['title']!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s['desc']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
''';

    content = content.replaceFirst(pattern, newHomeSection);
    file.writeAsStringSync(content);
    print('home_page.dart updated successfully.');
  } else {
    print('Pattern not matched');
  }
}
