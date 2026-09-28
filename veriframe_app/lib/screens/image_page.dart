import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ImagePage extends StatefulWidget {
  const ImagePage({super.key});

  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Local Image State
  File? _selectedImage;

  // Link Image State
  final TextEditingController _urlController = TextEditingController();

  // Status & Analysis State
  bool _isAnalyzing = false;
  String _statusMessage = '';
  Map<String, dynamic>? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _showServerDialog() async {
    final currentUrl = await VerifyBackendService.instance.getBaseUrl();
    if (!mounted) return;
    final controller = TextEditingController(text: currentUrl);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend API server URL (Default: Render cloud backend):',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'https://veriframe-backend-x3fn.onrender.com',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              controller.text = VerifyBackendService.defaultRemoteUrl;
              await VerifyBackendService.instance.saveBaseUrl(VerifyBackendService.defaultRemoteUrl);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset to Render Cloud Backend')),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Reset to Default'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await VerifyBackendService.instance.saveBaseUrl(newUrl);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Backend URL set to $newUrl')),
                  );
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (file != null) {
        setState(() {
          _selectedImage = File(file.path);
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _analyzeLocalImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _statusMessage = 'Uploading image to forensic engine...';
    });

    try {
      final baseUrl = await VerifyBackendService.instance.getBaseUrl();
      setState(() => _statusMessage = 'Running Biometrics, 2D FFT & Reality Defender AI...');
      final res = await VerifyBackendService.instance.verifyImage(baseUrl, _selectedImage!);

      setState(() {
        _result = res;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _analyzeLinkImage() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid HTTP/HTTPS image URL')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _statusMessage = 'Downloading image from URL...';
    });

    try {
      final baseUrl = await VerifyBackendService.instance.getBaseUrl();
      setState(() => _statusMessage = 'Running Biometrics, 2D FFT & Reality Defender AI...');
      final res = await VerifyBackendService.instance.verifyImageLink(baseUrl, url);

      setState(() {
        _result = res;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final onAppBar = Theme.of(context).colorScheme.onPrimary;

    return MainScaffold(
      backgroundColor: bg,
      showBack: true,
      title: const Text(
        'Image Forensics',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      extraActions: [
        IconButton(
          icon: const Icon(Icons.dns_outlined),
          tooltip: 'Backend Server',
          onPressed: _showServerDialog,
        ),
      ],
      appBarBottom: TabBar(
        controller: _tabController,
        labelColor: onAppBar,
        unselectedLabelColor: onAppBar.withValues(alpha: 0.7),
        indicatorColor: onAppBar,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.photo_library_rounded), text: 'Local Image'),
          Tab(icon: Icon(Icons.link_rounded), text: 'Image Link'),
        ],
      ),
      body: _result != null
          ? _buildResultView(isDark)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLocalTab(isDark),
                _buildLinkTab(isDark),
              ],
            ),
    );
  }

  Widget _buildLocalTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF162032) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          _buildInfoBanner(
            icon: Icons.auto_awesome,
            title: 'Dual-Engine Image Verification',
            subtitle: 'Combines VeriFrame 2D FFT frequency spectrum check with Reality Defender Cloud deepfake detector.',
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 20),

          // Upload Preview Container
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: _selectedImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () => setState(() => _selectedImage = null),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_rounded,
                            size: 40,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Select Image for Forensic Analysis',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Supports JPG, PNG, WEBP up to 50MB',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Action Buttons: Gallery or Camera
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('From Gallery'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Photo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Error Message
          if (_errorMessage != null) _buildErrorCard(_errorMessage!),

          // Status & Progress
          if (_isAnalyzing) ...[
            _buildScanningProgress(),
            const SizedBox(height: 20),
          ],

          // Verify Button
          ElevatedButton(
            onPressed: (_selectedImage != null && !_isAnalyzing) ? _analyzeLocalImage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              _isAnalyzing ? 'Analyzing Image...' : 'Verify Image Authenticity',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTab(bool isDark) {
    final cardBg = isDark ? const Color(0xFF162032) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoBanner(
            icon: Icons.link_rounded,
            title: 'Verify Image from Web Link',
            subtitle: 'Provide direct link to any online image (news sites, social media, CDNs) to check for deepfake tampering.',
            color: const Color(0xFF0D9488),
          ),
          const SizedBox(height: 24),

          // URL Input
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://example.com/image.jpg',
                border: InputBorder.none,
                icon: Icon(Icons.link, color: Color(0xFF0D9488)),
              ),
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) _buildErrorCard(_errorMessage!),

          if (_isAnalyzing) ...[
            _buildScanningProgress(),
            const SizedBox(height: 20),
          ],

          ElevatedButton(
            onPressed: !_isAnalyzing ? _analyzeLinkImage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              _isAnalyzing ? 'Fetching & Analyzing...' : 'Verify Image URL',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, height: 1.35, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningProgress() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const LinearProgressIndicator(color: Color(0xFF10B981)),
          const SizedBox(height: 12),
          Text(
            _statusMessage,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildResultView(bool isDark) {
    final r = _result!;
    final authScore = (r['authenticityScore'] as num?)?.toDouble() ?? 0.0;
    final fakeProb = (r['fakeProbability'] as num?)?.toDouble() ?? 0.0;
    final verdict = r['fineVerdict'] ?? r['verdict'] ?? 'UNKNOWN';
    final riskLevel = r['riskLevel'] ?? 'MEDIUM';
    final modelsUsed = r['modelsUsed'] ?? 'AI Ensemble';
    final observations = (r['forensicObservations'] as List<dynamic>?) ?? [];
    final evidence = (r['detectedEvidence'] as List<dynamic>?) ?? [];

    final isAuthentic = verdict == 'REAL' || verdict == 'LIKELY_REAL' || verdict == 'AUTHENTIC';
    final isFake = verdict == 'FAKE' || verdict == 'LIKELY_FAKE' || verdict == 'MANIPULATED';

    final verdictColor = isAuthentic
        ? const Color(0xFF10B981)
        : (isFake ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verdict Header Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [verdictColor.withValues(alpha: 0.18), verdictColor.withValues(alpha: 0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: verdictColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: verdictColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'VERDICT: $verdict',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'RISK: $riskLevel',
                        style: TextStyle(
                          color: verdictColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetricCol('Authenticity', '$authScore%', const Color(0xFF10B981)),
                    Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                    _buildMetricCol('Deepfake Prob', '$fakeProb%', const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Model Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162032) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    modelsUsed,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Evidence Section
          if (evidence.isNotEmpty) ...[
            const Text(
              'Detected Evidence',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...evidence.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.toString(), style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Observations Section
          if (observations.isNotEmpty) ...[
            const Text(
              'Forensic Observations',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...observations.map((obs) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      Expanded(child: Text(obs.toString(), style: const TextStyle(fontSize: 12, height: 1.3))),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // Button to test another image
          OutlinedButton(
            onPressed: () => setState(() {
              _result = null;
              _selectedImage = null;
              _urlController.clear();
            }),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Verify Another Image'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
