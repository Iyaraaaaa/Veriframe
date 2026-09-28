import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:veriframe_app/service/verify_backend_service.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  File? _selectedAudio;
  String? _audioFileName;
  int _audioFileSize = 0;

  bool _isAnalyzing = false;
  String _statusMessage = '';
  Map<String, dynamic>? _result;
  String? _errorMessage;

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

  Future<void> _pickAudioFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'],
      );

      if (res != null && res.files.single.path != null) {
        setState(() {
          _selectedAudio = File(res.files.single.path!);
          _audioFileName = res.files.single.name;
          _audioFileSize = res.files.single.size;
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick audio file: $e')),
        );
      }
    }
  }

  Future<void> _analyzeAudio() async {
    if (_selectedAudio == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _statusMessage = 'Uploading audio payload to forensic pipeline...';
    });

    try {
      final baseUrl = await VerifyBackendService.instance.getBaseUrl();
      setState(() => _statusMessage = 'Scanning acoustic spectrum & querying Reality Defender Voice AI...');
      final res = await VerifyBackendService.instance.verifyAudio(baseUrl, _selectedAudio!);

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

    return MainScaffold(
      backgroundColor: bg,
      showBack: true,
      title: const Text(
        'Audio Voice Forensics',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      ),
      extraActions: [
        IconButton(
          icon: const Icon(Icons.dns_outlined),
          tooltip: 'Backend Server',
          onPressed: _showServerDialog,
        ),
      ],
      body: _result != null ? _buildResultView(isDark) : _buildUploadView(isDark),
    );
  }

  Widget _buildUploadView(bool isDark) {
    final cardBg = isDark ? const Color(0xFF162032) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.record_voice_over_rounded, color: Color(0xFFF59E0B), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Voice Cloning & Synthetic Speech Detection',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Detects ElevenLabs, TTS vocoders, and AI speech synthesis using spectral band decomposition and Reality Defender Voice AI.',
                        style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Audio Selection Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              children: [
                if (_selectedAudio != null) ...[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.audiotrack_rounded,
                      size: 34,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _audioFileName ?? 'audio_file',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_audioFileSize / 1024).toStringAsFixed(1)} KB • ${(_audioFileName ?? '').split('.').last.toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _isAnalyzing ? null : _pickAudioFile,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Choose Different Audio'),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_none_rounded,
                      size: 40,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Audio File to Verify',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Supports MP3, WAV, M4A, AAC, FLAC up to 20MB',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _pickAudioFile,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Browse Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Container(
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
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (_isAnalyzing) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const LinearProgressIndicator(color: Color(0xFFF59E0B)),
                  const SizedBox(height: 12),
                  Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          ElevatedButton(
            onPressed: (_selectedAudio != null && !_isAnalyzing) ? _analyzeAudio : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              _isAnalyzing ? 'Analyzing Speech Patterns...' : 'Verify Audio Authenticity',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
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
    final modelsUsed = r['modelsUsed'] ?? 'Voice AI Ensemble';
    final observations = (r['forensicObservations'] as List<dynamic>?) ?? [];
    final evidence = (r['detectedEvidence'] as List<dynamic>?) ?? [];

    final isAuthentic = verdict == 'REAL' || verdict == 'LIKELY_REAL' || verdict == 'AUTHENTIC';
    final isFake = verdict == 'FAKE' || verdict == 'LIKELY_FAKE' || verdict == 'MANIPULATED';

    final verdictColor = isAuthentic
        ? const Color(0xFF10B981)
        : (isFake ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    final verdictLabel = isAuthentic
        ? 'AUTHENTIC HUMAN VOICE'
        : (isFake ? 'SYNTHETIC / CLONED VOICE' : 'UNCERTAIN SPEECH');

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
                        verdictLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
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
                    _buildMetricCol('Vocal Authenticity', '$authScore%', const Color(0xFF10B981)),
                    Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                    _buildMetricCol('Clone Risk', '$fakeProb%', const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Models Used
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162032) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.graphic_eq_rounded, color: Color(0xFFF59E0B), size: 20),
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

          // Detected Evidence
          if (evidence.isNotEmpty) ...[
            const Text(
              'Acoustic Anomalies Detected',
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

          // Observations
          if (observations.isNotEmpty) ...[
            const Text(
              'Spectral & Timeline Breakdown',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...observations.map((obs) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                      Expanded(child: Text(obs.toString(), style: const TextStyle(fontSize: 12, height: 1.3))),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
          ],

          OutlinedButton(
            onPressed: () => setState(() {
              _result = null;
              _selectedAudio = null;
              _audioFileName = null;
            }),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Verify Another Audio File'),
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
