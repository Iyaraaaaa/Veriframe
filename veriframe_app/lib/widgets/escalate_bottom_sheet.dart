import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
  static const String _whatsappNumber = '94784770935';
  static const String _emailAddress = 'sithmiyara2001@gmail.com';
  static const String _whatsappPackage = 'com.whatsapp';
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

  Future<void> _launchWhatsApp(String authorityTitle) async {
    final pdfFile = await _getPdfFile();
    if (pdfFile == null) {
      if (mounted) _showErrorSnackBar();
      return;
    }
    try {
      if (Platform.isAndroid) {
        final channel = MethodChannel(_methodChannel);
        await channel.invokeMethod('sharePdfToApp', {
          'filePath': pdfFile.path,
          'appPackage': _whatsappPackage,
          'recipient': _whatsappNumber,
          'subject': 'Forensic Report Escalation: $authorityTitle',
        });
      } else {
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'VeriFrame Forensic Report — $authorityTitle [${widget.report.verificationId}]',
          subject: 'Forensic Report Escalation: $authorityTitle',
        );
      }
    } catch (_) {
      if (mounted) _showErrorSnackBar();
    }
  }

  Future<void> _launchEmail(String authorityTitle) async {
    final pdfFile = await _getPdfFile();
    if (pdfFile == null) {
      if (mounted) _showErrorSnackBar();
      return;
    }
    try {
      if (Platform.isAndroid) {
        final channel = MethodChannel(_methodChannel);
        await channel.invokeMethod('sharePdfToApp', {
          'filePath': pdfFile.path,
          'appPackage': _gmailPackage,
          'recipient': _emailAddress,
          'subject': 'Forensic Report Escalation: $authorityTitle [${widget.report.verificationId}]',
        });
      } else {
        await Share.shareXFiles(
          [XFile(pdfFile.path)],
          text: 'VeriFrame Forensic Report — $authorityTitle [${widget.report.verificationId}]',
          subject: 'Forensic Report Escalation: $authorityTitle [${widget.report.verificationId}]',
        );
      }
    } catch (_) {
      if (mounted) _showErrorSnackBar();
    }
  }

  void _showErrorSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Couldn't open the app. Is it installed?"),
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
                          children: [
                            // WhatsApp button
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    final title = _selectedAuthority == 'cert'
                                        ? loc.verifyCertCc
                                        : loc.verifySriLankaPolice;
                                    _launchWhatsApp(title);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _whatsappGreen.withValues(
                                          alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _whatsappGreen.withValues(
                                            alpha: 0.4),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.chat_rounded,
                                          color: _whatsappGreen,
                                          size: 22,
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'WhatsApp',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _whatsappGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Email button
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    final title = _selectedAuthority == 'cert'
                                        ? loc.verifyCertCc
                                        : loc.verifySriLankaPolice;
                                    _launchEmail(title);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    decoration: BoxDecoration(
                                      color: accentBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: accentColor.withValues(
                                            alpha: 0.4),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.mail_rounded,
                                          color: accentColor,
                                          size: 22,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Email',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: accentColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
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