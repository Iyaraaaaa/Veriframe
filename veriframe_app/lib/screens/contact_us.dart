// lib/screens/contact_us.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/content_widgets.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;

  final String _supportEmail = 'support@veriframe.app';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isSending = false);
    if (!mounted) return;
    _nameController.clear();
    _emailController.clear();
    _messageController.clear();
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: context.colors.success,
            size: 28,
          ),
        ),
        title: Text(
          loc.contactSentTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          loc.contactSentBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textSubtle, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 16, top: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              loc.contactDone,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(ClipboardData(text: _supportEmail));
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${loc.contactEmail}: $_supportEmail ${loc.contactCopied}',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;

    return MainScaffold(
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                icon: Icons.mark_email_unread_outlined,
                title: loc.contactTitle,
                subtitle: loc.contactSubtitle,
              ),
              const SizedBox(height: 26),

              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.mail_outline_rounded,
                      label: loc.contactEmail,
                      value: _supportEmail,
                      onTap: _copyEmail,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.schedule_rounded,
                      label: loc.contactResponseTime,
                      value: loc.contactResponseValue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              SectionLabel(loc.contactSendMessageLabel),
              const SizedBox(height: 14),
              _Field(
                controller: _nameController,
                hint: loc.contactNameHint,
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    v == null || v.isEmpty ? loc.contactNameRequired : null,
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _emailController,
                hint: loc.contactEmailHint,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return loc.contactEmailRequired;
                  if (!v.contains('@')) return loc.contactEmailInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _messageController,
                hint: loc.contactMessageHint,
                icon: Icons.chat_bubble_outline_rounded,
                maxLines: 4,
                validator: (v) {
                  if (v == null || v.isEmpty) return loc.contactMessageRequired;
                  if (v.trim().length < 20) return loc.contactMessageMin;
                  return null;
                },
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: c.onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSending ? null : _submitForm,
                  child: _isSending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: c.onAccent,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              loc.contactSend,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: c.accent, size: 16),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: c.textSubtle,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: c.text,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return ThemedCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isMultiline = (maxLines ?? 1) > 1;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      validator: validator,
      style: TextStyle(color: c.text, fontSize: 13.5),
      cursorColor: c.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textSubtle, fontSize: 13.5),
        prefixIcon: isMultiline
            ? null
            : Icon(icon, color: c.textSubtle, size: 18),
        filled: true,
        fillColor: c.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
        errorStyle: TextStyle(color: c.danger, fontSize: 11.5),
      ),
    );
  }
}
