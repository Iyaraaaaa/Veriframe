import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  VERIFRAME  —  Verify Page
//  Deepfake detection analysis screen
// ─────────────────────────────────────────────

class VerifyPage extends StatefulWidget {
  final String? videoPath;
  final String? videoUrl;
  final String? streamUrl;

  const VerifyPage({super.key, this.videoPath, this.videoUrl, this.streamUrl});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage>
    with TickerProviderStateMixin {
  // ── State ───────────────────────────────────
  _AnalysisPhase _phase = _AnalysisPhase.idle;
  _Verdict? _verdict;

  double _efficientNetScore = 0;
  double _vitScore = 0;
  double _dfdcScore = 0;
  double _confidence = 0;

  int _framesExtracted = 0;
  int _totalFrames = 120;

  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnim;

  final List<String> _logLines = [];
  Timer? _analysisTimer;

  // ── Theme tokens ────────────────────────────
  static const _bg        = Color(0xFF080C14);
  static const _surface   = Color(0xFF0F1523);
  static const _border    = Color(0xFF1C2740);
  static const _accent    = Color(0xFF00C8FF);
  static const _danger    = Color(0xFFFF3B5C);
  static const _warn      = Color(0xFFFFB020);
  static const _safe      = Color(0xFF00E896);
  static const _textPri   = Color(0xFFE8F0FF);
  static const _textSec   = Color(0xFF6B7FA8);
  static const _card      = Color(0xFF111827);

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

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    if (widget.videoPath != null || widget.videoUrl != null) {
      Future.delayed(const Duration(milliseconds: 400), _startAnalysis);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _analysisTimer?.cancel();
    super.dispose();
  }

  // ── Simulated Analysis Pipeline ─────────────
  void _startAnalysis() {
    setState(() {
      _phase = _AnalysisPhase.extracting;
      _logLines.clear();
      _verdict = null;
      _efficientNetScore = 0;
      _vitScore = 0;
      _dfdcScore = 0;
      _confidence = 0;
      _framesExtracted = 0;
    });

    _log('▶ Initiating VERIFRAME forensic pipeline...');
    _log('▶ Input: ${widget.streamUrl ?? widget.videoUrl ?? widget.videoPath ?? "unknown"}');

    // Phase 1 — Frame extraction (0–2 s)
    int tick = 0;
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      tick++;

      if (tick <= 25) {
        // Frame extraction progress
        setState(() => _framesExtracted = (tick * (_totalFrames / 25)).round());
        if (tick == 5)  _log('▶ Normalizing resolution → 224×224');
        if (tick == 15) _log('▶ Preparing DFDC-style input tensors...');
        if (tick == 25) {
          _log('✔ ${_totalFrames} frames extracted');
          setState(() => _phase = _AnalysisPhase.efficientNet);
          _log('▶ EfficientNet spatial analysis started...');
        }
      } else if (tick <= 45) {
        // EfficientNet scoring
        final progress = (tick - 25) / 20;
        setState(() => _efficientNetScore = progress * 72);
        if (tick == 35) _log('▶ Detecting texture anomalies & GAN artifacts...');
        if (tick == 45) {
          _log('✔ EfficientNet score: ${_efficientNetScore.round()}%');
          setState(() => _phase = _AnalysisPhase.vit);
          _log('▶ Vision Transformer temporal analysis started...');
        }
      } else if (tick <= 65) {
        // ViT scoring
        final progress = (tick - 45) / 20;
        setState(() => _vitScore = progress * 81);
        if (tick == 55) _log('▶ Analyzing inter-frame identity consistency...');
        if (tick == 65) {
          _log('✔ ViT temporal score: ${_vitScore.round()}%');
          setState(() => _phase = _AnalysisPhase.dfdc);
          _log('▶ Matching against DFDC val/test distributions...');
        }
      } else if (tick <= 80) {
        // DFDC matching
        final progress = (tick - 65) / 15;
        setState(() => _dfdcScore = progress * 68);
        if (tick == 75) _log('▶ Computing dataset similarity score...');
        if (tick == 80) {
          _log('✔ DFDC pattern match: ${_dfdcScore.round()}%');
          setState(() => _phase = _AnalysisPhase.fusion);
          _log('▶ Fusion decision agent aggregating outputs...');
        }
      } else if (tick <= 95) {
        // Confidence ramp
        final progress = (tick - 80) / 15;
        final rawConf = (_efficientNetScore * 0.35 +
            _vitScore * 0.40 +
            _dfdcScore * 0.25);
        setState(() => _confidence = progress * rawConf);
      } else {
        t.cancel();
        final finalScore = (_efficientNetScore * 0.35 +
            _vitScore * 0.40 +
            _dfdcScore * 0.25);
        setState(() {
          _confidence = finalScore;
          _phase = _AnalysisPhase.done;
          _verdict = finalScore >= 75
              ? _Verdict.fake
              : finalScore >= 40
                  ? _Verdict.suspicious
                  : _Verdict.real;
        });
        _log('');
        _log('══════════════════════════════');
        _log('VERDICT: ${_verdictLabel(_verdict!)}');
        _log('CONFIDENCE: ${_confidence.round()}%');
        _log('══════════════════════════════');
      }
    });
  }

  void _log(String line) {
    setState(() => _logLines.add(line));
  }

  // ── UI ──────────────────────────────────────
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
                      const SizedBox(height: 16),
                      _buildScoreGrid(),
                      const SizedBox(height: 16),
                      if (_phase == _AnalysisPhase.done && _verdict != null)
                        _buildVerdictCard(),
                      if (_phase == _AnalysisPhase.done && _verdict != null)
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

  // ── Top bar ─────────────────────────────────
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
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _textSec, size: 18),
          ),
          const SizedBox(width: 12),
          // Logo mark
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
            child: const Icon(Icons.shield_rounded,
                color: Colors.white, size: 16),
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
          if (_phase != _AnalysisPhase.idle &&
              _phase != _AnalysisPhase.done)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: _pulseAnim.value,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 6,
                        height: 6,
                        child: _PulsingDot(color: _accent),
                      ),
                      SizedBox(width: 6),
                      Text('SCANNING',
                          style: TextStyle(
                              color: _accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5)),
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

  // ── Source card ──────────────────────────────
  Widget _buildSourceCard() {
    final source = widget.videoUrl ?? widget.videoPath ?? 'No source provided';
    final isUrl = widget.videoUrl != null;

    return _Card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            child: Icon(
              isUrl ? Icons.link_rounded : Icons.video_file_rounded,
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
                  isUrl ? 'Video URL' : 'Video File',
                  style: const TextStyle(
                      color: _textSec, fontSize: 11, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  source,
                  style: const TextStyle(
                      color: _textPri, fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_phase == _AnalysisPhase.idle)
            GestureDetector(
              onTap: _startAnalysis,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF0066FF), _accent]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Analyse',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Pipeline progress steps ──────────────────
  Widget _buildPipelineProgress() {
    final steps = [
      _PipelineStep('Frame Extraction', Icons.image_search_rounded,
          _AnalysisPhase.extracting),
      _PipelineStep('EfficientNet CNN', Icons.hub_rounded,
          _AnalysisPhase.efficientNet),
      _PipelineStep('Vision Transformer', Icons.timeline_rounded,
          _AnalysisPhase.vit),
      _PipelineStep('DFDC Matching', Icons.dataset_rounded,
          _AnalysisPhase.dfdc),
      _PipelineStep('Fusion Decision', Icons.merge_rounded,
          _AnalysisPhase.fusion),
    ];

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('ANALYSIS PIPELINE'),
          const SizedBox(height: 14),
          // Frame counter (only during extraction)
          if (_phase == _AnalysisPhase.extracting)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Frames extracted',
                          style: TextStyle(color: _textSec, fontSize: 12)),
                      Text('$_framesExtracted / $_totalFrames',
                          style: const TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _framesExtracted / _totalFrames,
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
    final stepIndex  = _AnalysisPhase.values.indexOf(step.phase);
    // idle = 0, done = 6
    final isDone    = phaseIndex > stepIndex;
    final isActive  = phaseIndex == stepIndex;
    final isPending = phaseIndex < stepIndex;

    final color = isDone
        ? _safe
        : isActive
            ? _accent
            : _textSec.withOpacity(0.4);

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
                    ? _accent.withOpacity(0.1 + 0.08 * _pulseAnim.value)
                    : isDone
                        ? _safe.withOpacity(0.08)
                        : _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withOpacity(isActive ? 0.7 : 0.3),
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded, color: _safe, size: 16)
                  : isActive
                      ? Icon(step.icon, color: _accent, size: 15)
                      : Icon(step.icon, color: _textSec.withOpacity(0.4), size: 15),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.label,
              style: TextStyle(
                color: isPending ? _textSec.withOpacity(0.4) : _textPri,
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
                child: const Text('Running...',
                    style: TextStyle(color: _accent, fontSize: 11)),
              ),
            ),
          if (isDone)
            const Text('Done',
                style: TextStyle(color: _safe, fontSize: 11)),
          if (isPending)
            const Text('Queued',
                style:
                    TextStyle(color: _textSec, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ── Score grid ───────────────────────────────
  Widget _buildScoreGrid() {
    return Row(
      children: [
        Expanded(
          child: _ScoreTile(
            label: 'EfficientNet',
            sublabel: 'Spatial',
            score: _efficientNetScore,
            icon: Icons.hub_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ScoreTile(
            label: 'ViT',
            sublabel: 'Temporal',
            score: _vitScore,
            icon: Icons.timeline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ScoreTile(
            label: 'DFDC',
            sublabel: 'Pattern',
            score: _dfdcScore,
            icon: Icons.dataset_rounded,
          ),
        ),
      ],
    );
  }

  // ── Verdict card ─────────────────────────────
  Widget _buildVerdictCard() {
    final v = _verdict!;
    final color  = _verdictColor(v);
    final label  = _verdictLabel(v);
    final icon   = _verdictIcon(v);
    final desc   = _verdictDescription(v);

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  Text('Confidence: ${_confidence.round()}%',
                      style: TextStyle(
                          color: color.withOpacity(0.7), fontSize: 13)),
                ],
              ),
              const Spacer(),
              _ConfidenceArc(score: _confidence, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: color.withOpacity(0.2),
          ),
          const SizedBox(height: 14),
          Text(desc,
              style: const TextStyle(
                  color: _textSec, fontSize: 13, height: 1.55)),
          if (v == _Verdict.fake) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _danger.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: _danger, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'HIGH RISK — Cybersecurity escalation recommended. DFDC-like manipulation pattern detected.',
                      style: TextStyle(
                          color: _danger, fontSize: 12, fontWeight: FontWeight.w500),
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

  // ── Activity log ─────────────────────────────
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
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _logLines.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Log copied'),
                        backgroundColor: _card,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Copy',
                      style: TextStyle(color: _accent, fontSize: 12)),
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
                      child: Text('Awaiting analysis...',
                          style: TextStyle(color: _textSec, fontSize: 12)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _logLines.length,
                    itemBuilder: (_, i) {
                      final line = _logLines[i];
                      final isVerdict = line.contains('VERDICT') ||
                          line.contains('CONFIDENCE') ||
                          line.startsWith('══');
                      return Text(
                        line,
                        style: TextStyle(
                          color: isVerdict
                              ? _verdictColor(_verdict ?? _Verdict.suspicious)
                              : line.startsWith('✔')
                                  ? _safe
                                  : _textSec,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: isVerdict
                              ? FontWeight.w700
                              : FontWeight.w400,
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

  // ── Bottom action bar ────────────────────────
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
        color: _bg,
      ),
      child: Row(
        children: [
          Expanded(
            child: _OutlineButton(
              label: 'Scan Another',
              icon: Icons.video_call_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PrimaryButton(
              label: 'Export Report',
              icon: Icons.download_rounded,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Generating forensic PDF report...'),
                    backgroundColor: _card,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────
  Color _verdictColor(_Verdict v) => switch (v) {
        _Verdict.real       => _safe,
        _Verdict.suspicious => _warn,
        _Verdict.fake       => _danger,
      };

  String _verdictLabel(_Verdict v) => switch (v) {
        _Verdict.real       => 'REAL',
        _Verdict.suspicious => 'SUSPICIOUS',
        _Verdict.fake       => 'FAKE',
      };

  IconData _verdictIcon(_Verdict v) => switch (v) {
        _Verdict.real       => Icons.verified_rounded,
        _Verdict.suspicious => Icons.error_outline_rounded,
        _Verdict.fake       => Icons.gpp_bad_rounded,
      };

  String _verdictDescription(_Verdict v) => switch (v) {
        _Verdict.real =>
          'No significant manipulation patterns detected. EfficientNet found no GAN artifacts in facial texture regions, and Vision Transformer temporal analysis shows consistent identity across all sampled frames. DFDC distribution alignment indicates authentic video.',
        _Verdict.suspicious =>
          'Moderate anomalies detected. Some temporal inconsistencies were identified between frames 34–67, with minor texture irregularities near the facial boundary. Pattern similarity to known DFDC deepfake samples is elevated. Manual review recommended.',
        _Verdict.fake =>
          'High-confidence deepfake detected. EfficientNet identified significant GAN-generated texture artifacts across facial regions. Vision Transformer detected identity drift across frame sequences. DFDC pattern match is highly correlated with known manipulation signatures.',
      };

  Widget _verdictBadge(_Verdict v) {
    final color = _verdictColor(v);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(_verdictLabel(v),
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
    );
  }
}

// ─────────────────────────────────────────────
//  Enums
// ─────────────────────────────────────────────

enum _AnalysisPhase {
  idle,
  extracting,
  efficientNet,
  vit,
  dfdc,
  fusion,
  done,
}

enum _Verdict { real, suspicious, fake }

// ─────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────

class _PipelineStep {
  final String label;
  final IconData icon;
  final _AnalysisPhase phase;
  const _PipelineStep(this.label, this.icon, this.phase);
}

// ─────────────────────────────────────────────
//  Shared Widgets
// ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1C2740)),
      ),
      child: child,
    );
  }
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
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final double score;
  final IconData icon;

  const _ScoreTile({
    required this.label,
    required this.sublabel,
    required this.score,
    required this.icon,
  });

  Color get _color {
    if (score >= 75) return const Color(0xFFFF3B5C);
    if (score >= 40) return const Color(0xFFFFB020);
    if (score > 0)   return const Color(0xFF00E896);
    return const Color(0xFF6B7FA8);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1C2740)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _color, size: 18),
          const SizedBox(height: 8),
          Text(
            score > 0 ? '${score.round()}%' : '--',
            style: TextStyle(
              color: _color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFE8F0FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          Text(sublabel,
              style: const TextStyle(
                  color: Color(0xFF6B7FA8), fontSize: 10)),
        ],
      ),
    );
  }
}

// Confidence arc (simple arc drawn via CustomPaint)
class _ConfidenceArc extends StatelessWidget {
  final double score;
  final Color color;
  const _ConfidenceArc({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: _ArcPainter(score: score / 100, color: color),
        child: Center(
          child: Text(
            '${score.round()}%',
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double score;
  final Color color;
  _ArcPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -2.35619; // -135°
    const sweepTotal = 4.71239;  // 270°

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepTotal, false, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepTotal * score, false, fgPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.score != score || old.color != color;
}

// Pulsing dot
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_a.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// Outline button
class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1C2740), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF6B7FA8), size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7FA8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// Primary button
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
              colors: [Color(0xFF0066FF), Color(0xFF00C8FF)]),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}