import 'dart:io';

void main() {
  final file = File(r'D:\VERI_FRAME\veriframe_app\lib\screens\verify.dart');
  if (!file.existsSync()) {
    print('File not found');
    return;
  }
  
  String content = file.readAsStringSync();

  // We'll replace the entire class `_VerifyPageState` and enums.
  // We can do this by finding `class _VerifyPageState extends State<VerifyPage>` 
  // up to the end of the file.
  
  final startIndex = content.indexOf('class _VerifyPageState extends State<VerifyPage>');
  if (startIndex == -1) {
    print('Start index not found');
    return;
  }
  
  final newContent = '''class _VerifyPageState extends State<VerifyPage> with TickerProviderStateMixin {
  _AnalysisPhase _phase = _AnalysisPhase.idle;
  _Verdict? _verdict;
  String? _selectedPath;

  double _authenticScore = 0;
  double _manipulatedScore = 0;
  double _confidence = 0;

  int _progressValue = 0;
  int _totalProgress = 100;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final List<String> _logLines = [];
  Timer? _analysisTimer;

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

  bool get _hasSource => _source != 'No source provided';

  String get _source {
    if (widget.videoUrl != null) return widget.videoUrl!;
    if (_selectedPath != null) return _selectedPath!;
    if (widget.videoPath != null) return widget.videoPath!;
    return 'No source provided';
  }

  bool get _isUrl => widget.videoUrl != null;

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

    if (_hasSource) {
      Future.delayed(const Duration(milliseconds: 400), _startAnalysis);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _analysisTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (!mounted) return;

    final file = result?.files.single;
    if (file == null) return;

    setState(() {
      _selectedPath = file.path ?? file.name;
    });

    Future.delayed(const Duration(milliseconds: 300), _startAnalysis);
  }

  void _startAnalysis() {
    if (_phase != _AnalysisPhase.idle && _phase != _AnalysisPhase.done) return;

    _analysisTimer?.cancel();

    setState(() {
      _phase = _AnalysisPhase.uploading;
      _logLines.clear();
      _verdict = null;
      _authenticScore = 0;
      _manipulatedScore = 0;
      _confidence = 0;
      _progressValue = 0;
    });

    _log('â–¶ Initiating VERIFRAME AI Analysis...');
    _log('â–¶ Source: \$_source');

    int tick = 0;
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      tick++;
      setState(() {
        _progressValue = tick;
      });

      if (tick <= 10) {
        if (tick == 2) _log('â–¶ Uploading Video...');
        if (tick == 10) {
          _log('âœ” Video Uploaded');
          setState(() => _phase = _AnalysisPhase.extracting);
        }
      } else if (tick <= 25) {
        if (tick == 12) _log('â–¶ Extracting Frames...');
        if (tick == 25) {
          _log('âœ” Frames Extracted');
          setState(() => _phase = _AnalysisPhase.detecting);
        }
      } else if (tick <= 40) {
        if (tick == 27) _log('â–¶ Detecting Faces...');
        if (tick == 40) {
          _log('âœ” Faces Detected');
          setState(() => _phase = _AnalysisPhase.efficientVit);
        }
      } else if (tick <= 55) {
        if (tick == 42) _log('â–¶ Running EfficientViT...');
        if (tick == 55) {
          _log('âœ” EfficientViT Analysis Complete');
          setState(() => _phase = _AnalysisPhase.crossEfficientVit);
        }
      } else if (tick <= 70) {
        if (tick == 57) _log('â–¶ Running CrossEfficientViT...');
        if (tick == 70) {
          _log('âœ” CrossEfficientViT Analysis Complete');
          setState(() => _phase = _AnalysisPhase.reasoning);
        }
      } else if (tick <= 85) {
        if (tick == 72) _log('â–¶ Generating Reasoning...');
        if (tick == 85) {
          _log('âœ” Reasoning Generated');
          setState(() => _phase = _AnalysisPhase.report);
        }
      } else if (tick <= 100) {
        if (tick == 87) _log('â–¶ Creating Report...');
        final rawConf = (tick - 85) / 15 * 88.0; // Mock score
        setState(() {
          _confidence = rawConf;
        });
      } else {
        t.cancel();

        // Mock final scores based on some random logic or hardcoded
        final finalConfidence = 88.0; 
        
        setState(() {
          _confidence = finalConfidence;
          _manipulatedScore = finalConfidence;
          _authenticScore = 100 - _manipulatedScore;
          _phase = _AnalysisPhase.done;
          
          if (_confidence >= 80) {
            _verdict = _Verdict.highRisk;
          } else if (_confidence >= 41) {
            _verdict = _Verdict.mediumRisk;
          } else {
            _verdict = _Verdict.lowRisk;
          }
        });

        _log('');
        _log('â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•');
        _log('RISK LEVEL: \${_verdictLabel(_verdict!)}');
        _log('CONFIDENCE: \${_confidence.round()}%');
        _log('â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•');
      }
    });
  }

  void _log(String line) {
    if (!mounted) return;
    setState(() => _logLines.add(line));
  }

  void _copyLog() {
    if (_logLines.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _logLines.join('\\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log copied'),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                      _buildPipelineProgress(),
                      
                      if (_phase == _AnalysisPhase.done && _verdict != null) ...[
                        const SizedBox(height: 16),
                        _buildResultsCard(),
                        const SizedBox(height: 16),
                        _buildExplainableAISection(),
                      ],
                      const SizedBox(height: 16),
                      _buildActivityLog(),
                    ],
                  ),
                ),
              ),
              if (_phase == _AnalysisPhase.done) _buildActionBar(),
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
          if (_phase != _AnalysisPhase.idle && _phase != _AnalysisPhase.done)
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
          if (_phase == _AnalysisPhase.done && _verdict != null)
            _verdictBadge(_verdict!),
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
              _isUrl ? Icons.link_rounded : Icons.video_file_rounded,
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
                  _isUrl ? 'Video URL' : 'Video File',
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
          if (_phase == _AnalysisPhase.idle)
            GestureDetector(
              onTap: _hasSource ? _startAnalysis : _pickVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0066FF), _accent],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _hasSource ? 'Analyze' : 'Select Video',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPipelineProgress() {
    final steps = [
      _PipelineStep('Uploading Video', Icons.cloud_upload_rounded, _AnalysisPhase.uploading),
      _PipelineStep('Extracting Frames', Icons.burst_mode_rounded, _AnalysisPhase.extracting),
      _PipelineStep('Detecting Faces', Icons.face_rounded, _AnalysisPhase.detecting),
      _PipelineStep('Running EfficientViT', Icons.memory_rounded, _AnalysisPhase.efficientVit),
      _PipelineStep('Running CrossEfficientViT', Icons.schema_rounded, _AnalysisPhase.crossEfficientVit),
      _PipelineStep('Generating Reasoning', Icons.psychology_rounded, _AnalysisPhase.reasoning),
      _PipelineStep('Creating Report', Icons.description_rounded, _AnalysisPhase.report),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('ANALYSIS PROGRESS'),
          const SizedBox(height: 14),
          if (_phase != _AnalysisPhase.idle && _phase != _AnalysisPhase.done)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Overall Progress',
                        style: TextStyle(color: _textSec, fontSize: 12),
                      ),
                      Text(
                        '\$_progressValue%',
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _progressValue / _totalProgress,
                    backgroundColor: _border,
                    valueColor: const AlwaysStoppedAnimation(_accent),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 5,
                  ),
                ],
              ),
            ),
          ...steps.map((s) => _buildPipelineRow(s)),
        ],
      ),
    );
  }

  Widget _buildPipelineRow(_PipelineStep step) {
    final phaseIndex = _AnalysisPhase.values.indexOf(_phase);
    final stepIndex = _AnalysisPhase.values.indexOf(step.phase);
    final isDone = phaseIndex > stepIndex;
    final isActive = phaseIndex == stepIndex;
    final isPending = phaseIndex < stepIndex;

    final color = isDone
        ? _safe
        : isActive
        ? _accent
        : _textSec.withValues(alpha:0.4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? _accent.withValues(alpha:0.1 + 0.08 * _pulseAnim.value)
                    : isDone
                    ? _safe.withValues(alpha:0.08)
                    : _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withValues(alpha:isActive ? 0.7 : 0.3),
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded, color: _safe, size: 16)
                  : isActive
                  ? Icon(step.icon, color: _accent, size: 15)
                  : Icon(step.icon, color: _textSec.withValues(alpha:0.4), size: 15),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.label,
              style: TextStyle(
                color: isPending ? _textSec.withValues(alpha:0.4) : _textPri,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isActive)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value,
                child: const Text(
                  'Running...',
                  style: TextStyle(color: _accent, fontSize: 11),
                ),
              ),
            ),
          if (isDone)
            const Text('Done', style: TextStyle(color: _safe, fontSize: 11)),
          if (isPending)
            const Text(
              'Queued',
              style: TextStyle(
                color: _textSec,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    final v = _verdict!;
    final color = _verdictColor(v);
    final label = _verdictLabel(v);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('AUTHENTICITY ANALYSIS'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Authentic', style: TextStyle(color: _textSec, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('\${_authenticScore.toStringAsFixed(1)}%', style: const TextStyle(color: _safe, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manipulated', style: TextStyle(color: _textSec, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('\${_manipulatedScore.toStringAsFixed(1)}%', style: const TextStyle(color: _danger, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _border),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confidence Score', style: TextStyle(color: _textSec, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('\${_confidence.toStringAsFixed(1)}%', style: const TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Risk Level', style: TextStyle(color: _textSec, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha:0.5)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExplainableAISection() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('WHY WAS THIS RESULT GENERATED?'),
          const SizedBox(height: 14),
          const Text(
            'The AI identified the following anomalies during frame-by-frame forensic analysis:',
            style: TextStyle(color: _textSec, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildIndicatorChip('Face Warping', true),
              _buildIndicatorChip('Lip Sync Issues', false),
              _buildIndicatorChip('Eye Movement Anomalies', false),
              _buildIndicatorChip('Lighting Inconsistencies', true),
              _buildIndicatorChip('Temporal Artifacts', true),
              _buildIndicatorChip('Synthetic Texture Patterns', true),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: const Text(
              'AI Explanation: High-confidence manipulation detected in the facial region. CrossEfficientViT identified synthetic texture patterns commonly generated by GANs. Significant temporal artifacts were found between frames 45-90, where the face warping and lighting inconsistencies are most prominent.',
              style: TextStyle(color: _textPri, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
            ),
          ),
          if (_verdict == _Verdict.highRisk) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _danger.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _danger.withValues(alpha:0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: _danger, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'âš  High-Risk Deepfake Detected',
                          style: TextStyle(color: _danger, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showReportingDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Report to Authorities'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndicatorChip(String label, bool detected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: detected ? _danger.withValues(alpha:0.1) : _safe.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: detected ? _danger.withValues(alpha:0.3) : _safe.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(detected ? Icons.close : Icons.check, size: 12, color: detected ? _danger : _safe),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: detected ? _danger : _safe, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildActivityLog() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel('FORENSIC LOG'),
              if (_logLines.isNotEmpty)
                GestureDetector(
                  onTap: _copyLog,
                  child: const Text(
                    'Copy',
                    style: TextStyle(color: _accent, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF070B12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: _logLines.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Awaiting analysis...',
                        style: TextStyle(color: _textSec, fontSize: 12),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _logLines.length,
                    itemBuilder: (_, i) {
                      final line = _logLines[i];
                      final isVerdict = line.contains('RISK LEVEL') ||
                          line.contains('CONFIDENCE') ||
                          line.startsWith('â•â•');
                      return Text(
                        line,
                        style: TextStyle(
                          color: isVerdict
                              ? _verdictColor(_verdict ?? _Verdict.mediumRisk)
                              : line.startsWith('âœ”')
                              ? _safe
                              : _textSec,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: isVerdict ? FontWeight.w700 : FontWeight.w400,
                          height: 1.7,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
        color: _bg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  label: 'View Detailed Report',
                  icon: Icons.analytics_rounded,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryButton(
                  label: 'Download Report',
                  icon: Icons.download_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Downloading report...'),
                        backgroundColor: _card,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  label: 'Share Report',
                  icon: Icons.share_rounded,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OutlineButton(
                  label: 'Scan Another',
                  icon: Icons.video_call_rounded,
                  onTap: () {
                    setState(() {
                      _selectedPath = null;
                      _phase = _AnalysisPhase.idle;
                      _verdict = null;
                      _logLines.clear();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _verdictColor(_Verdict v) => switch (v) {
        _Verdict.lowRisk       => _safe,
        _Verdict.mediumRisk => _warn,
        _Verdict.highRisk       => _danger,
      };

  String _verdictLabel(_Verdict v) => switch (v) {
        _Verdict.lowRisk       => 'Low Risk',
        _Verdict.mediumRisk => 'Medium Risk',
        _Verdict.highRisk       => 'High Risk',
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
  uploading,
  extracting,
  detecting,
  efficientVit,
  crossEfficientVit,
  reasoning,
  report,
  done,
}

enum _Verdict { lowRisk, mediumRisk, highRisk }

class _PipelineStep {
  final String label;
  final IconData icon;
  final _AnalysisPhase phase;
  _PipelineStep(this.label, this.icon, this.phase);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6B7FA8),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

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

  content = content.substring(0, startIndex) + newContent;
  file.writeAsStringSync(content);
  print('verify.dart updated successfully.');
}

