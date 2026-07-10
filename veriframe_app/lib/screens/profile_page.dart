import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class ProfilePage extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userImage;
  final Function(Locale) onLocaleChange;
  final Locale locale;
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userImage,
    required this.onLocaleChange,
    required this.locale,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400);
      if (picked == null) return;

      setState(() => _isLoading = true);
      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profileImageBase64': b64,
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userImage', 'data:image/jpeg;base64,$b64');
        if (mounted) setState(() {});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating image: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = widget.isDarkMode;

    return MainScaffold(
      showBack: true,
      title: const Text('Profile'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isLoading ? null : _pickAndUploadImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: widget.userImage.isNotEmpty
                            ? (widget.userImage.startsWith('data:')
                                ? MemoryImage(base64Decode(widget.userImage.split(',')[1]))
                                : NetworkImage(widget.userImage) as ImageProvider)
                            : const AssetImage('assets/images/empty.jpg') as ImageProvider,
                      ),
                      if (_isLoading)
                        const Positioned.fill(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.black45,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: VFColors.blue600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.userName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userEmail,
                  style: TextStyle(color: isDark ? VFColors.slate400 : VFColors.slate600, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Settings'),
          _buildCard([
            _buildTile(
              icon: Icons.language,
              title: 'Change Language',
              trailing: DropdownButton<String>(
                value: widget.locale.languageCode,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'si', child: Text('Sinhala')),
                  DropdownMenuItem(value: 'ta', child: Text('Tamil')),
                ],
                onChanged: (v) {
                  if (v != null) widget.onLocaleChange(Locale(v));
                },
              ),
            ),
            _buildTile(
              icon: isDark ? Icons.wb_sunny : Icons.nightlight_round,
              title: isDark ? 'Light Mode' : 'Dark Mode',
              onTap: () => widget.onThemeChanged(!isDark),
            ),
          ], isDark),
          const SizedBox(height: 24),
          _buildSectionTitle('About'),
          _buildCard([
            _buildTile(
              icon: Icons.info_outline,
              title: 'VeriFrame v1.0',
              subtitle: 'Forensic deepfake detection using EfficientViT and CrossEfficientViT',
              onTap: () => _showAbout(context),
            ),
          ], isDark),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? VFColors.navySurface : VFColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = widget.isDarkMode;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VFColors.blue600.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: VFColors.blue600, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, size: 18) : null),
      onTap: onTap,
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'VeriFrame',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(),
      children: [
        const Text(
          'Forensic deepfake detection platform powered by EfficientViT and CrossEfficientViT models. '
          'Designed for law enforcement and digital forensic investigators.',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
