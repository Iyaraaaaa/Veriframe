import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/models/report_model.dart';
import 'package:veriframe_app/service/notification_service.dart';
import 'package:veriframe_app/screens/report_detail_page.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/utils/theme.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _isNavigating = false;

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return "${difference.inDays}d ago";
    }
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    if (_uid == null || _isNavigating) return;

    setState(() => _isNavigating = true);

    try {
      // 1. Mark notification as read
      await NotificationService.instance.markAsRead(_uid!, notification.id);

      // 2. Fetch corresponding report details
      final reportDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('reports')
          .doc(notification.reportId)
          .get()
          .timeout(const Duration(seconds: 8));

      if (reportDoc.exists && mounted) {
        final report = ReportModel.fromMap(reportDoc.data()!, reportDoc.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailPage(report: report),
          ),
        );
      } else {
        throw Exception("Report file does not exist.");
      }
    } catch (e) {
      debugPrint('[NotificationsPage] Error tapping notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to open report: ${e.toString()}"),
            backgroundColor: VFColors.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final cardBg = VFColors.adaptiveCard(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);

    return MainScaffold(
      showBack: true,
      title: Text(loc.notifications ?? "Notifications"),
      body: _uid == null
          ? const Center(child: Text("User not logged in."))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumb Section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Home / Notifications",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ),
                
                // Notifications List Stream
                Expanded(
                  child: Stack(
                    children: [
                      StreamBuilder<List<NotificationModel>>(
                        stream: NotificationService.instance.getNotificationsStream(_uid!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: text)));
                          }
                          final notifications = snapshot.data ?? [];
                          if (notifications.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_off_outlined, size: 48, color: muted),
                                  const SizedBox(height: 12),
                                  Text(
                                    "No notifications yet.",
                                    style: TextStyle(color: muted, fontSize: 15),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: notifications.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemBuilder: (context, index) {
                              final notif = notifications[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: notif.isRead ? 1 : 3,
                                color: notif.isRead ? cardBg.withOpacity(0.8) : cardBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: notif.isRead
                                        ? Colors.transparent
                                        : VFColors.blue600.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () => _handleNotificationTap(notif),
                                  leading: CircleAvatar(
                                    backgroundColor: notif.isRead
                                        ? VFColors.slate400.withOpacity(0.15)
                                        : VFColors.blue600.withOpacity(0.15),
                                    child: Icon(
                                      Icons.notifications,
                                      color: notif.isRead ? VFColors.slate400 : VFColors.blue600,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif.title,
                                          style: TextStyle(
                                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                                            color: text,
                                          ),
                                        ),
                                      ),
                                      if (!notif.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        notif.message,
                                        style: TextStyle(color: notif.isRead ? muted : text, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif.videoName,
                                        style: TextStyle(color: muted, fontSize: 11, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    _formatTimeAgo(notif.createdAt),
                                    style: TextStyle(color: muted, fontSize: 11),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      if (_isNavigating)
                        Container(
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
