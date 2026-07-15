import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veriframe_app/screens/about_us.dart';
import 'package:veriframe_app/screens/contact_us.dart';
import 'package:veriframe_app/screens/notifications.dart';
import 'package:veriframe_app/screens/privacy.dart';
import 'package:veriframe_app/screens/delete_account.dart';
import 'package:veriframe_app/screens/edit_profile.dart';
import 'package:veriframe_app/screens/reports_page.dart';
import 'package:veriframe_app/service/notification_service.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/widgets/home_top_bar.dart';
import 'package:veriframe_app/widgets/content_widgets.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 2 tabs: Home (0) + Report (1)
  int _selectedIndex = 0;
  String _userName = "User Name";
  String _userEmail = "user@example.com";
  String _userImage = '';
  String _userId = '';

  final Map<String, Uint8List> _base64ImageCache = {};

  @override
  void initState() {
    super.initState();
    _loadCachedUserData();
    _loadUserData();
    // Initialize local notification plugin so it can fire after verifications
    NotificationService.instance.init();
  }

  Future<void> _loadCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userId = prefs.getString('userId') ?? '';
        _userName = prefs.getString('userName') ?? "User Name";
        _userEmail = prefs.getString('userEmail') ?? "user@example.com";
        _userImage = prefs.getString('userImage') ?? '';
      });
    }
  }

  Widget _getPageContent(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const ReportsPage(wrapped: false);
      default:
        return _buildHomeContent();
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _userId = currentUser.uid;
        _userEmail = currentUser.email ?? "user@example.com";

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (userDoc.exists && mounted) {
          final userData = userDoc.data();
          if (userData != null) {
            _userName =
                userData['name'] ?? currentUser.displayName ?? "User Name";
            _userEmail =
                userData['email'] ?? currentUser.email ?? "user@example.com";

            if (userData['profileImageBase64'] != null &&
                (userData['profileImageBase64'] as String).isNotEmpty) {
              _userImage =
                  'data:image/jpeg;base64,${userData['profileImageBase64']}';
            } else if (userData['imageUrl'] != null &&
                (userData['imageUrl'] as String).isNotEmpty) {
              _userImage = userData['imageUrl'];
            } else if (currentUser.photoURL?.isNotEmpty == true) {
              _userImage = currentUser.photoURL!;
            }
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _userId);
        await prefs.setString('userName', _userName);
        await prefs.setString('userEmail', _userEmail);
        if (_userImage.isNotEmpty) {
          await prefs.setString('userImage', _userImage);
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _getProfileImage({double radius = 20}) {
    if (_userImage.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: VFColors.blue600,
        child: Text(
          _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (_userImage.startsWith('data:image')) {
      try {
        final b64 = _userImage.split(',')[1];
        final bytes = _base64ImageCache[b64] ?? base64Decode(b64);
        _base64ImageCache[b64] = bytes;
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: VFColors.blue600,
          child: Text(
            _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(_userImage),
      );
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _navigateToAnalyze() => Navigator.pushNamed(context, '/analyze');

  void _openNotifications() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const NotificationsPage()),
  );

  void _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          userName: _userName,
          userEmail: _userEmail,
          userImage: _userImage,
        ),
      ),
    );
    if (result == true) await _loadUserData();
  }



  // ══════════════════════════════════════════
  //  HOME CONTENT
  // ══════════════════════════════════════════
  Widget _buildHomeContent() {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Welcome Hero Card ──
          _buildWelcomeCard(loc, isDark, c),
          const SizedBox(height: 28),

          // ── Quick Actions ──
          _buildQuickActions(loc, c),
          const SizedBox(height: 28),

          // ── What is VeriFrame? ──
          SectionLabel(loc.whatIsVeriFrame),
          const SizedBox(height: 10),
          ThemedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.whatIsDesc,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 16,
                      color: c.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      loc.forensicPlatform,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Features ──
          SectionLabel(loc.features),
          const SizedBox(height: 10),
          Column(
            children: [
              FeatureCard(
                icon: Icons.video_file_outlined,
                title: loc.featVideoVerification,
                description: loc.featVideoVerificationDesc,
                accent: c.accent,
              ),
              const SizedBox(height: 10),
              FeatureCard(
                icon: Icons.link_outlined,
                title: loc.featLinkVerification,
                description: loc.featLinkVerificationDesc,
                accent: c.accent,
              ),
              const SizedBox(height: 10),
              FeatureCard(
                icon: Icons.live_tv_outlined,
                title: loc.featLiveStream,
                description: loc.featLiveStreamDesc,
                accent: c.accent,
              ),
              const SizedBox(height: 10),
              FeatureCard(
                icon: Icons.psychology_outlined,
                title: loc.featAiReasoning,
                description: loc.featAiReasoningDesc,
                accent: c.accent,
              ),
              const SizedBox(height: 10),
              FeatureCard(
                icon: Icons.description_outlined,
                title: loc.featForensicReports,
                description: loc.featForensicReportsDesc,
                accent: c.accent,
              ),
              const SizedBox(height: 10),
              FeatureCard(
                icon: Icons.local_police_outlined,
                title: loc.featAuthorityReporting,
                description: loc.featAuthorityReportingDesc,
                accent: c.accent,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── How It Works ──
          SectionLabel(loc.howItWorks),
          const SizedBox(height: 10),
          _buildHowItWorks(isDark, c, loc),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(AppLocalizations loc, bool isDark, AppColors c) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark
              ? [VFColors.blue600, VFColors.navyDeep]
              : [VFColors.blue600, VFColors.blue700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: VFColors.blue600.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName != "User Name"
                        ? "Welcome, $_userName"
                        : "Welcome to VeriFrame",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.aiVideoAuth,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          loc.analyzeVideo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.shield_outlined,
                color: Colors.white.withValues(alpha: 0.9),
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppLocalizations loc, AppColors c) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.upload_file_outlined,
            label: loc.uploadVideo,
            color: VFColors.blue600,
            onTap: () => _navigateToAnalyze(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.link_outlined,
            label: loc.analyzeVideoLink,
            color: VFColors.emerald600,
            onTap: () => _navigateToAnalyze(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.live_tv_outlined,
            label: loc.analyzeLiveStream,
            color: VFColors.violet600,
            onTap: () => _navigateToAnalyze(),
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorks(bool isDark, AppColors c, AppLocalizations loc) {
    final steps = [
      {'num': '01', 'title': loc.stepUploadTitle, 'desc': loc.stepUploadDesc},
      {
        'num': '02',
        'title': loc.stepFaceDetectionTitle,
        'desc': loc.stepFaceDetectionDesc,
      },
      {
        'num': '03',
        'title': loc.stepAiAnalysisTitle,
        'desc': loc.stepAiAnalysisDesc,
      },
      {
        'num': '04',
        'title': loc.stepReasoningEngineTitle,
        'desc': loc.stepReasoningEngineDesc,
      },
      {
        'num': '05',
        'title': loc.stepAuthenticityScoreTitle,
        'desc': loc.stepAuthenticityScoreDesc,
      },
      {
        'num': '06',
        'title': loc.stepForensicReportTitle,
        'desc': loc.stepForensicReportDesc,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: steps.map((s) {
          final isLast = steps.indexOf(s) == steps.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: c.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    s['num']!,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['title']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s['desc']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainScaffold(
      appBar: HomeTopBar(onNotificationTap: _openNotifications),
      drawer: _buildDrawer(loc),

      // 2-tab body
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _getPageContent(0), // Home
          _getPageContent(1), // Report
        ],
      ),

      // 2-tab bottom nav: Home + Report
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? VFColors.gray800 : VFColors.gray200,
            ),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? VFColors.navyMid : VFColors.white,
          selectedItemColor: VFColors.blue600,
          unselectedItemColor: isDark ? VFColors.slate400 : VFColors.slate600,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: loc.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.description_outlined),
              activeIcon: const Icon(Icons.description),
              label: 'Report',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAnalyze,
        backgroundColor: VFColors.blue600,
        foregroundColor: VFColors.white,
        icon: const Icon(Icons.play_arrow),
        label: Text(loc.analyzeVideo),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  DRAWER  (Home, Settings, Notifications removed)
  // ══════════════════════════════════════════
  Widget _buildDrawer(AppLocalizations loc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? VFColors.navyMid : VFColors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _userName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              _userEmail,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            currentAccountPicture: _getProfileImage(radius: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [VFColors.blue600, VFColors.navyDeep]
                    : [VFColors.blue600, VFColors.blue700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            // Edit icon in header top-right area
            otherAccountsPictures: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _openEditProfile();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Reports, Privacy, About Us, Contact Us
          _buildDrawerItem(
            Icons.privacy_tip_outlined,
            loc.privacy,
            VFColors.emerald600,
            const PrivacyPage(),
          ),
          _buildDrawerItem(
            Icons.info_outline,
            loc.aboutUs,
            VFColors.blue600,
            const AboutUsPage(),
          ),
          _buildDrawerItem(
            Icons.phone_outlined,
            loc.contactUs,
            VFColors.amber600,
            const ContactUsPage(),
          ),

          const Divider(indent: 16, endIndent: 16),

          _buildDrawerItem(
            Icons.logout,
            loc.logOut,
            const Color(0xFF22C55E),
            const SizedBox(),
            isLogout: true,
          ),

          const SizedBox(height: 4),

          _buildDrawerItem(
            Icons.delete_forever_outlined,
            loc.deleteAccount,
            VFColors.red600,
            const SizedBox(),
            isDanger: true,
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => DeleteAccountDialog(
                  onConfirm: () =>
                      Navigator.pushReplacementNamed(context, '/welcome'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    Color iconColor,
    Widget page, {
    bool isLogout = false,
    bool isDanger = false,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDanger
        ? VFColors.red600
        : (isDark ? VFColors.slate200 : VFColors.gray800);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: (isDanger ? VFColors.red600 : iconColor).withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDanger ? VFColors.red600 : iconColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isDanger ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
          color: textColor,
        ),
      ),
      tileColor: isLogout
          ? (isDark
                ? VFColors.emerald600.withValues(alpha: 0.06)
                : const Color(0xFFF0FFF4))
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      onTap:
          onTap ??
          () async {
            Navigator.pop(context);
            if (isLogout) {
              await FirebaseAuth.instance.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            }
          },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
