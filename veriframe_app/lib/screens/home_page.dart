import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veriframe_app/screens/contact_us.dart';
import 'package:veriframe_app/screens/notifications.dart' as notif_screen;
import 'package:veriframe_app/screens/privacy.dart';
import 'package:veriframe_app/screens/about_us.dart';
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
import 'package:veriframe_app/service/user_profile_cache.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:veriframe_app/widgets/safe_avatar_widget.dart';

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

  // Stable decoded bytes – set once from cache synchronously so the drawer
  // avatar never blinks. Only updated when the image truly changes.
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    // ── Synchronous pre-fill from in-memory cache (no async, no blink) ──
    _seedFromCache();
    // ── Async loads (do NOT overwrite avatar unless data changed) ──
    _loadCachedUserData();
    _loadUserData();
    NotificationService.instance.init();
  }

  /// Reads the in-memory [UserProfileCache] synchronously so that the very
  /// first frame already has the correct avatar bytes – preventing any flicker
  /// when the drawer is opened immediately after navigating to HomePage.
  void _seedFromCache() {
    final cache = UserProfileCache.instance;
    if (cache.cachedImageBytes != null && cache.cachedImageBytes!.isNotEmpty) {
      _avatarBytes = cache.cachedImageBytes;
    }
    if (cache.userName.isNotEmpty) _userName = cache.userName;
    if (cache.userEmail.isNotEmpty) _userEmail = cache.userEmail;
    if (cache.cachedImageUrl != null && cache.cachedImageUrl!.isNotEmpty) {
      _userImage = cache.cachedImageUrl!;
    }
  }

  Future<void> _loadCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = UserProfileCache.instance;

    if (!mounted) return;

    final newName = cache.userName.isNotEmpty
        ? cache.userName
        : (prefs.getString('userName') ?? FirebaseAuth.instance.currentUser?.displayName ?? "User Name");
    final newEmail = cache.userEmail.isNotEmpty
        ? cache.userEmail
        : (prefs.getString('userEmail') ?? FirebaseAuth.instance.currentUser?.email ?? "user@example.com");
    final newId = prefs.getString('userId') ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    Uint8List? newBytes;
    String newImage = '';
    if (cache.cachedImageBytes != null && cache.cachedImageBytes!.isNotEmpty) {
      newBytes = cache.cachedImageBytes;
      newImage = 'data:image/jpeg;base64,${base64Encode(newBytes!)}';
    } else if (cache.cachedImageUrl != null && cache.cachedImageUrl!.isNotEmpty) {
      newImage = cache.cachedImageUrl!;
    } else {
      newImage = prefs.getString('userImage') ?? '';
    }

    // Only setState if something actually changed – avoids a redundant rebuild
    // that would cause the avatar to flicker on first drawer open.
    final avatarChanged = newBytes != null && newBytes != _avatarBytes;
    final textChanged = newName != _userName || newEmail != _userEmail || newId != _userId;
    if (avatarChanged || textChanged) {
      setState(() {
        _userId = newId;
        _userName = newName;
        _userEmail = newEmail;
        _userImage = newImage;
        if (newBytes != null) _avatarBytes = newBytes;
      });
    }

    if (newImage.isNotEmpty && !newImage.startsWith('data:image')) {
      try {
        precacheImage(CachedNetworkImageProvider(newImage), context);
      } catch (_) {}
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
        _userName = currentUser.displayName ?? _userName;
        _userImage = currentUser.photoURL ?? _userImage;

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (userDoc.exists && mounted) {
          final userData = userDoc.data();
          if (userData != null) {
            _userName =
                userData['name'] ?? currentUser.displayName ?? _userName;
            _userEmail =
                userData['email'] ?? currentUser.email ?? _userEmail;

            if (userData['profileImageBase64'] != null &&
                (userData['profileImageBase64'] as String).isNotEmpty) {
              _userImage =
                  'data:image/jpeg;base64,${userData['profileImageBase64']}';
            } else if (userData.containsKey('imageUrl') &&
                userData['imageUrl'] is String &&
                (userData['imageUrl'] as String).isNotEmpty) {
              _userImage = userData['imageUrl'];
            }
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _userId);
        await prefs.setString('userName', _userName);
        await prefs.setString('userEmail', _userEmail);

        // Decode the new image bytes once and compare with what's currently
        // displayed. Only call setState if the image actually changed so the
        // avatar never blinks due to a redundant Firestore round-trip.
        Uint8List? newBytes;
        if (_userImage.startsWith('data:image')) {
          try {
            newBytes = base64Decode(_userImage.split(',')[1]);
          } catch (_) {}
        }

        if (_userImage.isNotEmpty) {
          await prefs.setString('userImage', _userImage);
        } else {
          await prefs.remove('userImage');
        }
        UserProfileCache.instance.updateCache(
          name: _userName,
          email: _userEmail,
          bytes: newBytes,
          url: !_userImage.startsWith('data:image') && _userImage.isNotEmpty
              ? _userImage
              : null,
        );

        // Only rebuild if the decoded bytes actually differ (pointer or length).
        final imageChanged = newBytes != null &&
            (newBytes != _avatarBytes ||
                _avatarBytes == null ||
                newBytes.length != _avatarBytes!.length);
        if (mounted && imageChanged) {
          setState(() => _avatarBytes = newBytes);
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      // Only call setState for non-image state (name/email/userId) if needed.
      // Avatar is handled above — don't call an extra setState here that would
      // cause the drawer header to repaint and flicker the avatar.
      if (mounted) {
        setState(() {});
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        NotificationService.instance.refreshBadge(uid);
      }
    }
  }

  Widget _getProfileImage({double radius = 20}) {
    // Prefer the stable decoded bytes held directly in state – no re-decode,
    // no string round-trip, no flicker.
    final bytes = _avatarBytes ?? UserProfileCache.instance.cachedImageBytes;

    return SafeAvatarWidget(
      radius: radius,
      imageUrl: (bytes == null || bytes.isEmpty) &&
              _userImage.isNotEmpty &&
              !_userImage.startsWith('data:')
          ? _userImage
          : null,
      imageBytes: bytes,
      fallbackName: _userName,
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _navigateToAnalyze() => Navigator.pushNamed(context, '/analyze');

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const notif_screen.NotificationsPage()),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      NotificationService.instance.refreshBadge(uid);
    }
  }

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
    final cardBg = VFColors.adaptiveCard(isDark);
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroBanner(loc),
          const SizedBox(height: 16),
          _buildStatsStrip(isDark, text, muted),

          const SizedBox(height: 32),

           // ── What is VeriFrame? ──
          _sectionTitle(loc.whatIsVeriFrame, text),
          const SizedBox(height: 12),
          _buildAboutCard(loc, isDark, cardBg, text, muted),
          const SizedBox(height: 32),

          // ── Features ──
          _sectionTitle(loc.features, text),
          const SizedBox(height: 14),
          _buildFeaturesCard(isDark, cardBg, text, muted),
          const SizedBox(height: 32),

          // ── How It Works ──
          _sectionTitle(loc.howItWorks, text),
          const SizedBox(height: 14),
          _buildNewHowItWorksCard(isDark, cardBg, text, muted),
          const SizedBox(height: 28),
          _buildFooter(text, muted),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(AppLocalizations loc) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/landing.jpg',
            height: 230,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 230,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ),
        Container(
          height: 230,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 15,
                      width: 15,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'VeriFrame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                loc.aiVideoAuth,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsStrip(bool isDark, Color text, Color muted) {
    final loc = AppLocalizations.of(context)!;
    final stats = [
      (Icons.auto_awesome, loc.homeStatsAiModels, 'EfficientViT'),
      (Icons.speed, loc.homeStatsRealtime, loc.homeStatsLiveAnalysis),
      (Icons.verified_user, loc.homeStatsForensic, loc.homeStatsEvidenceReports),
    ];
    final divider = Container(
      width: 1,
      height: 40,
      color: isDark ? VFColors.gray800 : VFColors.gray200,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: VFColors.adaptiveCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? VFColors.gray800 : VFColors.gray200,
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VFColors.blue600.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stats[i].$1, color: VFColors.blue600, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    stats[i].$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stats[i].$3,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            if (i < stats.length - 1) divider,
          ],
        ],
      ),
    );
  }

  Widget _buildAboutCard(
    AppLocalizations loc,
    bool isDark,
    Color cardBg,
    Color text,
    Color muted,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? VFColors.gray800 : VFColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VeriFrame',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: text,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            loc.whatIsDesc,
            style: TextStyle(fontSize: 14, color: text, height: 1.6),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard(
    bool isDark,
    Color cardBg,
    Color text,
    Color muted,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? VFColors.gray800 : VFColors.gray200,
        ),
      ),
      child: Column(
        children: _featureItems.asMap().entries.map((e) {
          final f = e.value;
          final isLast = e.key == _featureItems.length - 1;
          return Column(
            children: [
              _buildFeatureRow(f.$1, f.$2, f.$3, isDark),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 56,
                  endIndent: 8,
                  color: isDark ? VFColors.gray800 : VFColors.gray200,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooter(Color text, Color muted) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 18, width: 18),
            const SizedBox(width: 8),
            Text(
              'VeriFrame',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: text,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          loc.homeFooterTagline,
          style: TextStyle(fontSize: 12, color: muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          loc.homeCopyright(DateTime.now().year),
          style: TextStyle(fontSize: 11, color: muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<(String, String, IconData)> get _featureItems {
    final loc = AppLocalizations.of(context)!;
    return [
      (loc.featVideoVerification, loc.featVideoVerificationDesc, Icons.video_file),
      (loc.featLinkVerification, loc.featLinkVerificationDesc, Icons.link),
      (loc.featLiveStream, loc.featLiveStreamDesc, Icons.live_tv),
      (loc.featAiReasoning, loc.featAiReasoningDesc, Icons.psychology),
      (loc.featForensicReports, loc.featForensicReportsDesc, Icons.description),
      (loc.featAuthorityReporting, loc.featAuthorityReportingDesc, Icons.local_police),
    ];
  }

  Widget _sectionTitle(String title, Color text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: VFColors.blue600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: text,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    String title,
    String desc,
    IconData icon,
    bool isDark,
  ) {
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VFColors.blue600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: VFColors.blue600, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewHowItWorksCard(
    bool isDark,
    Color cardBg,
    Color text,
    Color muted,
  ) {
    final loc = AppLocalizations.of(context)!;
    final steps = [
      {'title': loc.stepUploadTitle, 'desc': loc.stepUploadDesc},
      {'title': loc.stepFaceDetectionTitle, 'desc': loc.stepFaceDetectionDesc},
      {'title': loc.stepAiAnalysisTitle, 'desc': loc.stepAiAnalysisDesc},
      {
        'title': loc.stepReasoningEngineTitle,
        'desc': loc.stepReasoningEngineDesc,
      },
      {
        'title': loc.stepAuthenticityScoreTitle,
        'desc': loc.stepAuthenticityScoreDesc,
      },
      {
        'title': loc.stepForensicReportTitle,
        'desc': loc.stepForensicReportDesc,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          int idx = entry.key;
          var s = entry.value;
          bool isLast = idx == steps.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: VFColors.blue600,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: VFColors.blue600.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['title']!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s['desc']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
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
              label: loc.reportTab,
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

          // About Us, Privacy, Contact Us
          _buildDrawerItem(
            Icons.info_outlined,
            loc.aboutUs,
            VFColors.blue600,
            const AboutUsPage(),
          ),
          _buildDrawerItem(
            Icons.privacy_tip_outlined,
            loc.privacy,
            VFColors.emerald600,
            const PrivacyPage(),
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
               showModalBottomSheet(
                 context: context,
                 isScrollControlled: true,
                 backgroundColor: Colors.transparent,
                 builder: (_) => const DeleteAccountDialog(),
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

