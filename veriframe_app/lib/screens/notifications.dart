import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/service/notification_service.dart';
import 'package:veriframe_app/utils/theme.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final Set<String> _removedNotificationIds = {};
  bool _isNavigating = false;

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return "just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    } else {
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    if (_uid == null || _isNavigating) return;

    setState(() => _isNavigating = true);

    try {
      await NotificationService.instance.markAsRead(_uid!, notification.id);
      if (mounted) {
        Navigator.pushNamed(context, '/reports');
      }
    } catch (e) {
      debugPrint('[NotificationsPage] Error tapping notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to open notification: ${e.toString()}"),
            backgroundColor: VFColors.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  Future<void> _markAllAsRead() async {
    if (_uid == null) return;
    await NotificationService.instance.markAllAsRead(_uid!);
  }

  Future<void> _removeNotification(String id) async {
    setState(() {
      _removedNotificationIds.add(id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Notification removed"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = VFColors.adaptiveText(isDark);
    final muted = VFColors.adaptiveTextSecondary(isDark);
    final accent = Theme.of(context).colorScheme.primary;

    return MainScaffold(
      showBack: true,
      title: Row(
        children: [
          Icon(Icons.notifications_outlined, size: 20, color: text),
          const SizedBox(width: 10),
          Text(loc.notifications),
        ],
      ),
      extraActions: [
        StreamBuilder<int>(
          stream: _uid != null
              ? NotificationService.instance.getUnreadCountStream(_uid!)
              : const Stream.empty(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: _markAllAsRead,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Mark all read'),
            );
          },
        ),
      ],
      body: _uid == null
          ? Center(
              child: Text(
                "User not logged in.",
                style: TextStyle(color: muted),
              ),
            )
          : Column(
              children: [
                _buildHeader(isDark, text, muted),
                Expanded(
                  child: Stack(
                    children: [
                      StreamBuilder<List<NotificationModel>>(
                        stream: NotificationService.instance
                            .getNotificationsStream(_uid!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                "Error: ${snapshot.error}",
                                style: TextStyle(color: text),
                              ),
                            );
                          }
                          final notifications = snapshot.data!
                              .where((n) => !_removedNotificationIds.contains(n.id))
                              .toList();
                          if (notifications.isEmpty) {
                            return _buildEmptyState(isDark, text, muted);
                          }

                          return ListView.separated(
                            itemCount: notifications.length,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final notif = notifications[index];
                              return _buildNotificationTile(notif, isDark, text, muted, accent);
                            },
                          );
                        },
                      ),
                      if (_isNavigating)
                        Container(
                          color: Colors.black.withOpacity(0.4),
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

  Widget _buildHeader(bool isDark, Color text, Color muted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: VFColors.adaptiveCard(isDark),
        border: Border(
          bottom: BorderSide(
            color: isDark ? VFColors.gray800 : VFColors.gray200,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<int>(
            stream: NotificationService.instance.getUnreadCountStream(_uid!),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: unread > 0 ? VFColors.blue600 : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unread > 0
                        ? '$unread pending verification update${unread > 1 ? 's' : ''}'
                        : "No unread alerts",
                    style: TextStyle(
                      color: text,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            "Review history of digital verification scan logs below.",
            style: TextStyle(color: muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color text, Color muted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: muted.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: muted,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "All caught up!",
              style: TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You will receive local push updates and database logs when completed forensic reports compile.",
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
    NotificationModel notif,
    bool isDark,
    Color text,
    Color muted,
    Color accent,
  ) {
    final isFake = notif.prediction.toUpperCase() == 'FAKE';
    final statusColor = isFake ? VFColors.red600 : VFColors.emerald600;
    final statusBg = isFake ? VFColors.red50 : VFColors.emerald50;
    final statusBgDark = isFake ? VFColors.red600.withOpacity(0.15) : VFColors.emerald600.withOpacity(0.15);
    final scorePct = notif.score > 1.0 ? notif.score.round() : (notif.score * 100).round();

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeNotification(notif.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: VFColors.red600.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded, color: VFColors.red600, size: 24),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: VFColors.adaptiveCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? VFColors.gray800 : VFColors.gray200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleNotificationTap(notif),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? statusBgDark : statusBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFake ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: TextStyle(
                                  fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                  fontSize: 14,
                                  color: text,
                                ),
                              ),
                            ),
                            if (!notif.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _chip(
                              label: notif.prediction.toUpperCase() == 'FAKE' ? 'MANIPULATED' : 'AUTHENTIC',
                              color: statusColor,
                              bg: isDark ? statusBgDark : statusBg,
                            ),
                            const SizedBox(width: 8),
                            _chip(
                              label: '$scorePct% score',
                              color: text,
                              bg: isDark ? VFColors.gray800 : VFColors.gray100,
                            ),
                            const Spacer(),
                            Text(
                              _formatTimeAgo(notif.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: muted,
                                fontWeight: FontWeight.w500,
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
          ),
        ),
      ),
    );
  }

  Widget _chip({required String label, required Color color, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}
