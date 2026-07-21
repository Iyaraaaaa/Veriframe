import 'dart:io';

void main() {
  final file = File(r'D:\VERI_FRAME\veriframe_app\lib\screens\verify.dart');
  String content = file.readAsStringSync();

  final stateStart = content.indexOf('class _VerifyPageState extends State<VerifyPage>');
  
  if (stateStart != -1) {
    String newState = '''class _VerifyPageState extends State<VerifyPage> with TickerProviderStateMixin {
  _AnalysisPhase _phase = _AnalysisPhase.idle;
  _Verdict? _verdict;

  double _authenticScore = 0;
  double _manipulatedScore = 0;
  double _confidence = 0;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const String _baseUrl = 'http://10.0.2.2:3000';
  
  static const _bg = Color(0xFF080C14);
  static const _surface = Color(0xFF0F1523);
  static const _border = Color(0xFF1C2740);
  static const _accent = Color(0xFF00C8FF);
  static const _danger = Color(0xFFFF3B5C);
  static const _warn = Color(0xFFFFB020);
  static const _safe = Color(0xFF00E896);
  static const _textPri = Color(0xFFE8F0FF);
  static const _textSec = Color(0xFF6B7FA8);
  static const _card = Color(0xFF111827);

  String get _source {
    if (widget.videoUrl != null) return widget.videoUrl!;
    if (widget.streamUrl != null) return widget.streamUrl!;
    if (widget.videoPath != null) return widget.videoPath!;
    return 'No source provided';
  }

  bool get _isUrl => widget.videoUrl != null || widget.streamUrl != null;
  bool get _isStream => widget.streamUrl != null;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_source != 'No source provided') {
      Future.delayed(const Duration(milliseconds: 400), _startAnalysis);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    if (_phase != _AnalysisPhase.idle && _phase != _AnalysisPhase.done) return;

    setState(() {
      _phase = _AnalysisPhase.analyzing;
      _verdict = null;
      _errorMessage = null;
      _authenticScore = 0;
      _manipulatedScore = 0;
      _confidence = 0;
    });

    try {
      http.Response response;
      final timeout = const Duration(seconds: 60);

      if (widget.videoPath != null) {
        var request = http.MultipartRequest('POST', Uri.parse('\$_baseUrl/analyze-video'));
        request.files.add(await http.MultipartFile.fromPath('file', widget.videoPath!));
        var streamedResponse = await request.send().timeout(timeout);
        response = await http.Response.fromStream(streamedResponse).timeout(timeout);
      } else if (widget.videoUrl != null) {
        response = await http.post(
          Uri.parse('\$_baseUrl/analyze-url'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': widget.videoUrl}),
        ).timeout(timeout);
      } else if (widget.streamUrl != null) {
        response = await http.post(
          Uri.parse('\$_baseUrl/analyze-stream'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'stream_url': widget.streamUrl}),
        ).timeout(timeout);
      } else {
        throw Exception('No valid source');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']);
        }
        
        setState(() {
          _authenticScore = (data['authenticity_score'] ?? 0).toDouble();
          _manipulatedScore = (data['manipulation_score'] ?? 0).toDouble();
          _confidence = (data['confidence'] ?? 0).toDouble();

          final risk = data['risk_level']?.toString().toUpperCase();
          if (risk == 'HIGH' || _manipulatedScore >= 80) {
            _verdict = _Verdict.highRisk;
          } else if (risk == 'MEDIUM') {
            _verdict = _Verdict.mediumRisk;
          } else {
            _verdict = _Verdict.lowRisk;
          }

          _phase = _AnalysisPhase.done;
        });
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Server error \${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _AnalysisPhase.done;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        
        final lowerError = _errorMessage!.toLowerCase();
        if (lowerError.contains('weights not installed') || lowerError.contains('pth not found') || lowerError.contains('missing weights')) {
          _errorMessage = 'Model weights not installed.';
        } else if (lowerError.contains('connection refused') || lowerError.contains('failed host lookup') || lowerError.contains('timeout') || e is TimeoutException || e is SocketException) {
          _errorMessage = 'AI service unavailable.';
        }
      });
    }
  }

  void _showReportingDialog() {
    bool confirmChecked = false;
    bool consentChecked = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: _surface,
              title: const Text('Report to Authorities', style: TextStyle(color: _textPri)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please review the report details before submitting to the authorities. False reporting may result in penalties.',
                      style: TextStyle(color: _textSec, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Sri Lanka CERT (SLCERT)', style: TextStyle(color: _textPri)),
                      leading: const Icon(Icons.security, color: _accent),
                      tileColor: _card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Sri Lanka Police (Cyber Crime)', style: TextStyle(color: _textPri)),
                      leading: const Icon(Icons.local_police, color: _accent),
                      tileColor: _card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: confirmChecked,
                      onChanged: (val) => setState(() => confirmChecked = val ?? false),
                      title: const Text('I confirm the details in the forensic report are accurate to the best of my knowledge.', style: TextStyle(color: _textSec, fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: _accent,
                      checkColor: _bg,
                    ),
                    CheckboxListTile(
                      value: consentChecked,
                      onChanged: (val) => setState(() => consentChecked = val ?? false),
                      title: const Text('I consent to share this video and analysis data with the selected authorities.', style: TextStyle(color: _textSec, fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: _accent,
                      checkColor: _bg,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: _textSec)),
                ),
                ElevatedButton(
                  onPressed: (confirmChecked && consentChecked) ? () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted successfully to authorities.'), backgroundColor: _safe),
                    );
                  } : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _danger, foregroundColor: Colors.white),
                  child: const Text('Submit Report'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      _buildSourceCard(),
                      const SizedBox(height: 16),
                      
                      if (_phase == _AnalysisPhase.analyzing)
                        _buildLoadingState(),
                      
                      if (_phase == _AnalysisPhase.done && _errorMessage != null)
                        _buildErrorState(),

                      if (_phase == _AnalysisPhase.done && _errorMessage == null && _verdict != null)
                        _buildResultsCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textSec,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                colors: [Color(0xFF0066FF), _accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'VERIFRAME',
            style: TextStyle(
              color: _textPri,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          if (_phase == _AnalysisPhase.analyzing)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withValues(alpha:0.4)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 6,
                        height: 6,
                        child: _PulsingDot(color: _accent),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'ANALYZING',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceCard() {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withValues(alpha:0.2)),
            ),
            child: Icon(
              _isStream ? Icons.live_tv_rounded : _isUrl ? Icons.link_rounded : Icons.video_file_rounded,
              color: _accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isStream ? 'Live Stream' : _isUrl ? 'Video URL' : 'Video File',
                  style: const TextStyle(
                    color: _textSec,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _source,
                  style: const TextStyle(
                    color: _textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return _Card(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            CircularProgressIndicator(color: _accent),
            SizedBox(height: 20),
            Text(
              'Analyzing via AI Engine...',
              style: TextStyle(color: _textPri, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Running MTCNN, EfficientViT and CrossEfficientViT...',
              style: TextStyle(color: _textSec, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _danger.withValues(alpha:0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: _danger, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Analysis Failed',
            style: TextStyle(color: _danger, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textPri, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          _OutlineButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onTap: _startAnalysis,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final v = _verdict!;
    final color = _verdictColor(v);
    final label = _verdictLabel(v);
    final isHighRisk = _manipulatedScore >= 80;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isHighRisk)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _danger.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _danger.withValues(alpha:0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _danger, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'âš  High Risk',
                    style: TextStyle(color: _danger, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border, width: 1),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Authenticity:', style: TextStyle(color: _textSec, fontSize: 16)),
                  Text('\${_authenticScore.toStringAsFixed(1)}%', style: const TextStyle(color: _safe, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Manipulated:', style: TextStyle(color: _textSec, fontSize: 16)),
                  Text('\${_manipulatedScore.toStringAsFixed(1)}%', style: const TextStyle(color: _danger, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Confidence:', style: TextStyle(color: _textSec, fontSize: 16)),
                  Text('\${_confidence.toStringAsFixed(1)}%', style: const TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Risk:', style: TextStyle(color: _textSec, fontSize: 16)),
                  Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        if (isHighRisk) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  label: 'Download Report',
                  icon: Icons.download_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading report...'), backgroundColor: _card),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryButton(
                  label: 'Report',
                  icon: Icons.warning_amber_rounded,
                  onTap: _showReportingDialog,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _verdictColor(_Verdict v) => switch (v) {
        _Verdict.lowRisk       => _safe,
        _Verdict.mediumRisk => _warn,
        _Verdict.highRisk       => _danger,
      };

  String _verdictLabel(_Verdict v) => switch (v) {
        _Verdict.lowRisk       => 'Low',
        _Verdict.mediumRisk => 'Medium',
        _Verdict.highRisk       => 'High',
      };

  Widget _verdictBadge(_Verdict v) {
    final color = _verdictColor(v);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha:0.5)),
      ),
      child: Text(_verdictLabel(v).toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
    );
  }
}

enum _AnalysisPhase {
  idle,
  analyzing,
  done,
}

enum _Verdict { lowRisk, mediumRisk, highRisk }

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1C2740)),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0066FF), Color(0xFF00C8FF)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1C2740)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE8F0FF), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE8F0FF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha:0.5),
            blurRadius: 4,
            spreadRadius: 1,
          )
        ],
      ),
    );
  }
}
''';

    content = content.replaceRange(stateStart, content.length, newState);
    file.writeAsStringSync(content);
    print('verify.dart updated successfully.');
  } else {
    print('Could not find state block');
  }
}

