import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/service/notification_service.dart';
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
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    if (_uid == null || _isNavigating) return;

    setState(() => _isNavigating = true);

    try {
      await NotificationService.instance.markAsRead(_uid, notification.id);
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
    await NotificationService.instance.markAllAsRead(_uid);
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .doc(notification.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Notification deleted")));
      }
    } catch (e) {
      debugPrint('[NotificationsPage] Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't delete notification: ${e.toString()}"),
            backgroundColor: VFColors.red600,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.colors;

    return MainScaffold(
      showBack: true,
      title: Row(
        children: [
          Icon(Icons.notifications_outlined, size: 19, color: c.text),
          const SizedBox(width: 9),
          Text(loc.notifications),
        ],
      ),
      extraActions: [
        StreamBuilder<int>(
          stream: _uid != null
              ? NotificationService.instance.getUnreadCountStream(_uid)
              : const Stream.empty(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: _markAllAsRead,
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
                style: TextStyle(color: c.textMuted),
              ),
            )
          : Column(
              children: [
                _buildHeader(c),
                Expanded(
                  child: Stack(
                    children: [
                      StreamBuilder<List<NotificationModel>>(
                        stream: NotificationService.instance
                            .getNotificationsStream(_uid),
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
                                style: TextStyle(color: c.text),
                              ),
                            );
                          }
                          final notifications = snapshot.data ?? [];
                          if (notifications.isEmpty) {
                            return _buildEmptyState(c);
                          }

                          return ListView.separated(
                            itemCount: notifications.length,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final notif = notifications[index];
                              return _buildNotificationTile(notif, c);
                            },
                          );
                        },
                      ),
                      if (_isNavigating)
                        Container(
                          color: c.surface.withValues(alpha: 0.7),
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

  Widget _buildHeader(AppColors c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<int>(
            stream: NotificationService.instance.getUnreadCountStream(_uid!),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return Text(
                unread > 0
                    ? '$unread new update${unread > 1 ? 's' : ''}'
                    : "You're all caught up",
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            "Stay informed about your verification results.",
            style: TextStyle(color: c.textMuted, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 36,
              color: c.textSubtle,
            ),
            const SizedBox(height: 16),
            Text(
              "No notifications yet.",
              style: TextStyle(
                color: c.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "When a verification finishes, you'll see the result here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notif, AppColors c) {
    final isFake = notif.prediction.toUpperCase() == 'FAKE';
    final accent = isFake ? VFColors.red600 : VFColors.emerald600;
    final scorePct = (notif.score * 100).round();

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(notif),
      onDismissed: (_) => _deleteNotification(notif),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: VFColors.red600.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline_rounded, color: VFColors.red600),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notif),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isFake
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontWeight: notif.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                fontSize: 14,
                                color: c.text,
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: c.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: c.textSubtle,
                            ),
                            onPressed: () async {
                              final confirmed = await _confirmDelete(notif);
                              if (confirmed) _deleteNotification(notif);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _chip(
                            label: notif.prediction.toUpperCase(),
                            color: accent,
                          ),
                          _chip(label: '$scorePct%', color: c.textMuted),
                          if (notif.videoName.isNotEmpty)
                            Text(
                              notif.videoName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: c.textSubtle,
                              ),
                            ),
                          const Spacer(),
                          Text(
                            _formatTimeAgo(notif.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textSubtle,
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
    );
  }

  Future<bool> _confirmDelete(NotificationModel notif) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete notification?'),
        content: Text('This will remove "${notif.title}" permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: VFColors.red600),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _chip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}
