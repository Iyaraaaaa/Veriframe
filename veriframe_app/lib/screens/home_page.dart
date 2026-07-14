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
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 2 tabs only: Home (0) + Verify (1)
  int _selectedIndex = 0;
  String _userName = "User Name";
  String _userEmail = "user@example.com";
  String _userImage = '';
  String _userId = '';
  bool _isLoadingUserData = true;

  final Map<String, Uint8List> _base64ImageCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Initialize local notification plugin so it can fire after verifications
    NotificationService.instance.init();
  }

  Widget _getPageContent(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return VerifyPage(wrapped: false);
      default:
        return _buildHomeContent();
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoadingUserData = true);

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
      } else {
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
    } catch (e) {
      debugPrint('Error loading user data: $e');
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _userId = prefs.getString('userId') ?? '';
          _userName = prefs.getString('userName') ?? "User Name";
          _userEmail = prefs.getString('userEmail') ?? "user@example.com";
          _userImage = prefs.getString('userImage') ?? '';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
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

  Widget _buildLastScanOverview(bool isDark, Color cardBg, Color text, Color muted) {
    if (_userId.isEmpty) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircularProgressIndicator(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
            ),
            child: Column(
              children: [
                Text(
                  "No scans performed yet",
                  style: TextStyle(fontWeight: FontWeight.bold, color: text, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  "Verify a video in the Verify tab to generate reports.",
                  style: TextStyle(color: muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        final doc = snapshot.data!.docs.first;
        final report = ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        final isReal = report.prediction == 'REAL';
        final scoreColor = isReal ? VFColors.emerald600 : VFColors.red600;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: report.score / 100.0,
                      strokeWidth: 5,
                      backgroundColor: isDark ? VFColors.gray800 : VFColors.gray200,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                  Text(
                    "${report.score.toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "LAST VERIFICATION RESULT",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: muted, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.videoName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          isReal ? "Authentic" : "Manipulated",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scoreColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(report.createdAt),
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_forward_ios, size: 14, color: muted),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportDetailPage(report: report),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentReportsList(bool isDark, Color cardBg, Color text, Color muted) {
    if (_userId.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Forensic Scans",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/reports'),
              child: const Text("View All", style: TextStyle(fontSize: 12, color: VFColors.blue600)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .collection('reports')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("No scan reports found.", style: TextStyle(color: muted, fontSize: 12)),
              );
            }
            final docs = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final report = ReportModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                final isReal = report.prediction == 'REAL';
                Widget thumbnailWidget;
                if (report.thumbnail.isNotEmpty) {
                  try {
                    final bytes = base64Decode(report.thumbnail);
                    thumbnailWidget = ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(bytes, width: 36, height: 36, fit: BoxFit.cover),
                    );
                  } catch (_) {
                    thumbnailWidget = _buildHomePlaceholderThumbnail(isReal);
                  }
                } else {
                  thumbnailWidget = _buildHomePlaceholderThumbnail(isReal);
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: cardBg,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isDark ? VFColors.gray800 : VFColors.gray200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    leading: thumbnailWidget,
                    title: Text(
                      report.videoName,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          isReal ? "REAL" : "FAKE",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isReal ? VFColors.emerald600 : VFColors.red600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Score: ${report.score.toStringAsFixed(0)}%",
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 12, color: muted),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetailPage(report: report),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildHomePlaceholderThumbnail(bool isReal) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: (isReal ? VFColors.emerald600 : VFColors.red600).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        isReal ? Icons.verified_user : Icons.gavel,
        color: isReal ? VFColors.emerald600 : VFColors.red600,
        size: 18,
      ),
    );
  }

  Widget _buildRecentNotificationsList(bool isDark, Color cardBg, Color text, Color muted) {
    if (_userId.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Notifications",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text),
            ),
            TextButton(
              onPressed: _openNotifications,
              child: const Text("View All", style: TextStyle(fontSize: 12, color: VFColors.blue600)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .collection('notifications')
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("No recent notifications.", style: TextStyle(color: muted, fontSize: 12)),
              );
            }
            final docs = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final notif = NotificationModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: cardBg,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: notif.isRead 
                          ? (isDark ? VFColors.gray800 : VFColors.gray200)
                          : VFColors.blue600.withOpacity(0.4),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: notif.isRead 
                          ? VFColors.slate400.withOpacity(0.1) 
                          : VFColors.blue600.withOpacity(0.1),
                      radius: 14,
                      child: Icon(
                        Icons.notifications_outlined, 
                        color: notif.isRead ? VFColors.slate400 : VFColors.blue600, 
                        size: 14
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                              color: text
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      notif.message,
                      style: TextStyle(fontSize: 11, color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 12, color: muted),
                    onTap: () async {
                      await NotificationService.instance.markAsRead(_userId, notif.id);
                      final reportDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_userId)
                          .collection('reports')
                          .doc(notif.reportId)
                          .get();
                      if (reportDoc.exists && mounted) {
                        final report = ReportModel.fromMap(reportDoc.data()!, reportDoc.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportDetailPage(report: report),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile row with pencil edit icon ──
          Row(
            children: [
              Stack(
                children: [
                  _getProfileImage(radius: 26),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _openEditProfile,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: VFColors.blue600,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? VFColors.navyMid : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_userName.split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VeriFrame Forensic Detection Platform',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: VFColors.emerald600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: VFColors.emerald600.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: VFColors.emerald600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      loc.online,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: VFColors.emerald600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildLastScanOverview(isDark, cardBg, text, muted),
          const SizedBox(height: 24),
          _buildRecentReportsList(isDark, cardBg, text, muted),
          const SizedBox(height: 24),
          _buildRecentNotificationsList(isDark, cardBg, text, muted),
          const SizedBox(height: 28),

          // ── Hero Section ──
          Center(
            child: Column(
              children: [
                Text(
                  'VeriFrame',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: text,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.aiVideoAuth,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: VFColors.blue600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc.heroDesc1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: text,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc.heroDesc2,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── What is VeriFrame? ──
          Text(
            loc.whatIsVeriFrame,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? VFColors.gray800 : VFColors.gray200,
              ),
            ),
            child: Text(
              loc.whatIsDesc,
              style: TextStyle(fontSize: 14, color: text, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),

          // ── Features Cards ──
          Text(
            loc.features,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _buildFeatureCard(
                loc.featVideoVerification,
                loc.featVideoVerificationDesc,
                Icons.video_file,
                isDark,
              ),
              _buildFeatureCard(
                loc.featLinkVerification,
                loc.featLinkVerificationDesc,
                Icons.link,
                isDark,
              ),
              _buildFeatureCard(
                loc.featLiveStream,
                loc.featLiveStreamDesc,
                Icons.live_tv,
                isDark,
              ),
              _buildFeatureCard(
                loc.featAiReasoning,
                loc.featAiReasoningDesc,
                Icons.psychology,
                isDark,
              ),
              _buildFeatureCard(
                loc.featForensicReports,
                loc.featForensicReportsDesc,
                Icons.description,
                isDark,
              ),
              _buildFeatureCard(
                loc.featAuthorityReporting,
                loc.featAuthorityReportingDesc,
                Icons.local_police,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── How It Works ──
          Text(
            loc.howItWorks,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          _buildNewHowItWorksCard(isDark, cardBg, text, muted),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    String desc,
    IconData icon,
    bool isDark,
  ) {
    final cardBg = VFColors.adaptiveCard(isDark);
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? VFColors.gray800 : VFColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VFColors.blue600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: VFColors.blue600, size: 20),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(fontSize: 11, color: muted, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
      appBar: HomeTopBar(
        onNotificationTap: _openNotifications,
      ),
      drawer: _buildDrawer(loc),

      // 2-tab body
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _getPageContent(0), // Home
          _getPageContent(1), // Verify
        ],
      ),

      // 2-tab bottom nav: Home + Verify
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
              icon: const Icon(Icons.videocam_outlined),
              activeIcon: const Icon(Icons.videocam),
              label: loc.verify,
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
            accountName: _isLoadingUserData
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
            accountEmail: _isLoadingUserData
                ? const Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  )
                : Text(
                    _userEmail,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
            currentAccountPicture: _isLoadingUserData
                ? const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : _getProfileImage(radius: 30),
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
            Icons.assessment_outlined,
            "Forensic Reports",
            VFColors.blue600,
            const ReportsPage(),
          ),
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
