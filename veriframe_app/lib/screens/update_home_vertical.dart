import 'dart:io';

void main() {
  final file = File(r'D:\VERI_FRAME\veriframe_app\lib\screens\home_page.dart');
  String content = file.readAsStringSync();

  final pattern = RegExp(r'  // ══════════════════════════════════════════\r?\n  //  VERIFY CONTENT\r?\n  // ══════════════════════════════════════════\r?\n  Widget _buildVerifyContent\(\) \{.*?(?=  @override\r?\n  Widget build\(BuildContext context\))', dotAll: true);
  
  if (pattern.hasMatch(content)) {
    String newSection = '''  // ══════════════════════════════════════════
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 24),

          // Upload Video Section
          _buildVerifyMethodCard(
            title: 'Upload Video',
            description: 'Select a local video file.',
            icon: Icons.upload_file,
            isDark: isDark,
            cardBg: cardBg,
            text: text,
            muted: muted,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFiles(type: FileType.video);
                  if (!context.mounted) return;
                  if (result != null && result.files.single.path != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => VerifyPage(videoPath: result.files.single.path)));
                  }
                },
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
          ),
          const SizedBox(height: 16),

          // Analyze Video Link Section
          _buildVerifyMethodCard(
            title: 'Analyze Link',
            description: 'Paste a public video URL.',
            icon: Icons.link,
            isDark: isDark,
            cardBg: cardBg,
            text: text,
            muted: muted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _linkController,
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_linkController.text.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => VerifyPage(videoUrl: _linkController.text)));
                      }
                    },
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
          const SizedBox(height: 16),

          // Analyze Live Stream Section
          _buildVerifyMethodCard(
            title: 'Live Stream',
            description: 'Paste a live stream URL.',
            icon: Icons.live_tv,
            isDark: isDark,
            cardBg: cardBg,
            text: text,
            muted: muted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _streamController,
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_streamController.text.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => VerifyPage(streamUrl: _streamController.text)));
                      }
                    },
                    icon: const Icon(Icons.cast),
                    label: const Text('Start Monitoring'),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: VFColors.blue600, size: 24),
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
          const SizedBox(height: 8),
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
''';

    content = content.replaceFirst(pattern, newSection);
    file.writeAsStringSync(content);
    print('home_page.dart layout updated to vertical.');
  } else {
    print('Pattern not matched in home_page.dart');
  }
}
