import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/verification_result.dart';
import 'package:veriframe_app/service/pdf_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme-aware palette (mirrors the _Pal pattern from reports_page.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _EscalPal {
  final bool isDark;
  const _EscalPal(this.isDark);

  Color get bg => isDark ? const Color(0xFF0F1523) : const Color(0xFFFFFFFF);
  Color get surfaceMuted =>
      isDark ? const Color(0xFF162035) : const Color(0xFFF7F8FA);
  Color get border => isDark ? const Color(0xFF1A2233) : const Color(0xFFE3E6EB);
  Color get textPrimary =>
      isDark ? const Color(0xFFE8F0FF) : const Color(0xFF14181F);
  Color get textSecondary =>
      isDark ? const Color(0xFF8B9DC3) : const Color(0xFF667085);
  Color get textSubtle =>
      isDark ? const Color(0xFF6B7FA8) : const Color(0xFF98A2B3);

  static const manipulated = Color(0xFFC1483F);
  Color get manipulatedBg =>
      isDark ? const Color(0x33C1483F) : const Color(0xFFFBEDEC);
  Color get data =>
      isDark ? const Color(0xFF64B5F6) : const Color(0xFF35608F);
}

// ─────────────────────────────────────────────────────────────────────────────
// EscalateBottomSheet — shared widget used by both ReportsPage and VerifyPage
// ─────────────────────────────────────────────────────────────────────────────

/// A polished bottom-sheet widget for escalating a forensic report to a national
/// authority. On Android, shares the pre-generated PDF directly to WhatsApp or Gmail
/// via platform channels. On iOS, uses the system share sheet.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => EscalateBottomSheet(report: myResult),
/// );
/// ```
class EscalateBottomSheet extends StatefulWidget {
  const EscalateBottomSheet({super.key, required this.report});

  final VerificationResult report;

  @override
  State<EscalateBottomSheet> createState() => _EscalateBottomSheetState();
}

class _EscalateBottomSheetState extends State<EscalateBottomSheet> {
  static const Color _whatsappGreen = Color(0xFF25D366);

  /// Authority WhatsApp contact in international format (no +, no spaces).
  static const String _whatsappNumber = '94784770935';

  /// Human-readable form of [_whatsappNumber] shown in the UI.
  static const String _whatsappDisplay = '078 477 0935';

  /// Authority email that receives the forensic PDF.
  static const String _emailAddress = 'sithmiyara2001@gmail.com';

  static const String _gmailPackage = 'com.google.android.gm';
  static const String _methodChannel = 'com.veriframe_app/share_pdf';

  String? _selectedAuthority;

  _EscalPal get _pal =>
      _EscalPal(Theme.of(context).brightness == Brightness.dark);

  // ── Helpers ──────────────────────────────────────────────────────

  /// Ensures the forensic report PDF exists and returns the file.
  /// If the report already has a valid pdfPath, uses that file.
  /// Otherwise generates a new PDF via PdfService.
  Future<File?> _getPdfFile() async {
    final r = widget.report;
    if (r.pdfPath != null && r.pdfPath!.isNotEmpty && File(r.pdfPath!).existsSync()) {
      return File(r.pdfPath!);
    }
    try {
      final file = await PdfService.instance.generateReportPdf(result: r);
      return file;
    } catch (e) {
      debugPrint('[EscalateBottomSheet] PDF generation failed: $e');
      return null;
    }
  }

  /// Plain-text summary sent alongside the report so the authority gets the
  /// essential finding even when the PDF cannot be attached (WhatsApp deep
  /// links do not carry attachments).
  String _buildReportText(String authorityTitle) {
    final r = widget.report;
    final lines = <String>[
      'VeriFrame — ${AppLocalizations.of(context)!.escalateReportTitle}',
      'Authority: $authorityTitle',
      'Report ID: ${r.verificationId}',
      'Media: ${r.mediaName ?? r.source}',
      'Type: ${r.mediaType}',
      'Verdict: ${r.verdict}',
      'Risk: ${r.riskLevel}',
      'Authenticity: ${r.authenticityScore.toStringAsFixed(1)}%',
      'Deepfake probability: ${r.fakeProbability.toStringAsFixed(1)}%',
      'Confidence: ${(r.confidence * 100).toStringAsFixed(1)}%',
      'Report hash: ${r.reportHash}',
      'Analysed: ${r.verifiedAt.toIso8601String()}',
    ];
    if (r.detectedEvidence.isNotEmpty) {
      lines.add('Evidence: ${r.detectedEvidence.join(', ')}');
    }
    return lines.join('\n');
  }

  String _emailSubject(String authorityTitle) {
    final r = widget.report;
    return 'Forensic Report Escalation: $authorityTitle [${r.verificationId}]';
  }

  /// Opens a WhatsApp chat with [_whatsappNumber] and a pre-filled message.
  /// ACTION_SEND cannot address a specific contact, so the official wa.me
  /// deep link is used — it is the only way to guarantee the report lands in
  /// the authority's chat instead of a contact picker.
  Future<void> _launchWhatsApp(String authorityTitle) async {
    final message = _buildReportText(authorityTitle);
    final waUri = Uri.https('wa.me', '/$_whatsappNumber', {'text': message});

    if (Platform.isAndroid) {
      try {
        await const MethodChannel(_methodChannel).invokeMethod<bool>(
          'openWhatsAppChat',
          {'phone': _whatsappNumber, 'message': message},
        );
        return;
      } catch (e) {
        debugPrint('[EscalateBottomSheet] WhatsApp channel failed: $e');
        // Fall through to the wa.me link (browser / WhatsApp Business).
      }
    }

    try {
      final opened = await launchUrl(
        waUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('launchUrl returned false');
    } catch (e) {
      debugPrint('[EscalateBottomSheet] wa.me fallback failed: $e');
      if (mounted) _showErrorSnackBar();
    }
  }

  /// Sends the generated PDF to the authority email. Falls back to a
  /// mailto: compose link when Gmail is unavailable.
  Future<void> _launchEmail(String authorityTitle) async {
    final body = _buildReportText(authorityTitle);
    final subject = _emailSubject(authorityTitle);
    final pdfFile = await _getPdfFile();

    if (Platform.isAndroid && pdfFile != null) {
      try {
        await const MethodChannel(_methodChannel).invokeMethod<bool>(
          'sharePdfToApp',
          {
            'filePath': pdfFile.path,
            'appPackage': _gmailPackage,
            'recipient': _emailAddress,
            'subject': subject,
            'body': body,
          },
        );
        return;
      } catch (e) {
        debugPrint('[EscalateBottomSheet] Gmail share failed: $e');
        // Fall through to the mailto: compose link.
      }
    }

    try {
      final opened = await launchUrl(
        Uri(
          scheme: 'mailto',
          path: _emailAddress,
          queryParameters: {'subject': subject, 'body': body},
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('launchUrl returned false');
    } catch (e) {
      debugPrint('[EscalateBottomSheet] mailto fallback failed: $e');
      if (mounted) _showErrorSnackBar();
    }
  }

  /// Shares the PDF through the system sheet so the user can attach it to the
  /// authority chat (or any other channel) themselves.
  Future<void> _attachPdf(String authorityTitle) async {
    final pdfFile = await _getPdfFile();
    if (pdfFile == null) {
      if (mounted) _showErrorSnackBar();
      return;
    }
    try {
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        text: _buildReportText(authorityTitle),
        subject: _emailSubject(authorityTitle),
      );
    } catch (_) {
      if (mounted) _showErrorSnackBar();
    }
  }

  void _showErrorSnackBar() {
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.escalateSendFailed),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final pal = _pal;

    // Accent colour: cyan in dark mode, the app's data-blue in light mode
    final Color accentColor = pal.isDark
        ? const Color(0xFF00E5FF)
        : const Color(0xFF35608F);
    final Color accentBg = accentColor.withValues(alpha: 0.12);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: pal.border, width: 1),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ─────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: pal.textSubtle.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header row ──────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: pal.manipulatedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: _EscalPal.manipulated,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.escalateReportTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loc.escalateReportSubtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Section label: AUTHORITY ────────────────────────────────────
            Text(
              loc.authoritySectionLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: pal.textSubtle,
              ),
            ),
            const SizedBox(height: 10),

            // ── Authority tile 1: CERT|CC ───────────────────────────────────
            _buildAuthorityTile(
              id: 'cert',
              title: loc.verifyCertCc,
              subtitle: 'National cyber security incident response',
              icon: Icons.dns_rounded,
              accentColor: accentColor,
              accentBg: accentBg,
              pal: pal,
            ),
            const SizedBox(height: 10),

            // ── Authority tile 2: Sri Lanka Police CID ──────────────────────
            _buildAuthorityTile(
              id: 'cid',
              title: loc.verifySriLankaPolice,
              subtitle: 'Cybercrime Investigation Division',
              icon: Icons.local_police_rounded,
              accentColor: accentColor,
              accentBg: accentBg,
              pal: pal,
            ),

            // ── Animated "SEND VIA" section ─────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _selectedAuthority == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          loc.sendViaLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: pal.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // WhatsApp → 078 477 0935
                            Expanded(
                              child: _buildSendButton(
                                label: 'WhatsApp',
                                destination: _whatsappDisplay,
                                icon: Icons.chat_rounded,
                                color: _whatsappGreen,
                                onTap: () => _launchWhatsApp(_authorityTitle(loc)),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Gmail → sithmiyara2001@gmail.com
                            Expanded(
                              child: _buildSendButton(
                                label: 'Email',
                                destination: _emailAddress,
                                icon: Icons.mail_rounded,
                                color: accentColor,
                                onTap: () => _launchEmail(_authorityTitle(loc)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildAttachButton(loc),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _authorityTitle(AppLocalizations loc) =>
      _selectedAuthority == 'cert' ? loc.verifyCertCc : loc.verifySriLankaPolice;

  Widget _buildSendButton({
    required String label,
    required String destination,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final pal = _pal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                destination,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.25,
                  color: pal.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Secondary action: hand the generated PDF to the system share sheet so it
  /// can be attached to the authority chat (WhatsApp deep links cannot carry
  /// file attachments).
  Widget _buildAttachButton(AppLocalizations loc) {
    final pal = _pal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _attachPdf(_authorityTitle(loc)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: pal.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.attach_file_rounded, size: 18, color: pal.textSecondary),
              const SizedBox(width: 8),
              Text(
                loc.escalateAttachPdf,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: pal.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorityTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color accentBg,
    required _EscalPal pal,
  }) {
    final isSelected = _selectedAuthority == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedAuthority = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? accentBg : pal.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accentColor : pal.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.15)
                      : pal.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? accentColor : pal.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: accentColor,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}