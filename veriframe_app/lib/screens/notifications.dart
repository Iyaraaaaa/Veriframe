import 'dart:async';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _markAllAsReadOnOpen();
  }

  Future<void> _markAllAsReadOnOpen() async {
    if (_uid == null) return;
    await NotificationService.instance.markAllAsRead(_uid);
  }

  String _formatTimeAgo(BuildContext context, DateTime dateTime) {
    final loc = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return loc.notificationsJustNow;
    } else if (difference.inMinutes < 60) {
      return loc.notificationsMinutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return loc.notificationsHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return loc.notificationsDaysAgo(difference.inDays);
    } else {
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    }
  }

  Future<void> _markAllAsRead() async {
    if (_uid == null) return;
    await NotificationService.instance.markAllAsRead(_uid);
  }

  Future<void> _removeNotification(
    String id,
    NotificationModel notification,
  ) async {
    if (_uid == null) return;
    await NotificationService.instance.deleteNotification(_uid, id);
  }

  @override
  void dispose() {
    super.dispose();
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
          Icon(Icons.notifications_outlined, size: 18, color: text),
          const SizedBox(width: 8),
          Text(
            loc.notifications,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
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
                foregroundColor: accent,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(loc.notificationsMarkAllRead(count > 99 ? '99+' : count.toString())),
            );
          },
        ),
      ],
      body: _uid == null
          ? Center(
              child: Text(
                loc.notificationsNotLoggedIn,
                style: TextStyle(color: muted),
              ),
            )
          : Expanded(
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
                            loc.notificationsError(snapshot.error.toString()),
                            style: TextStyle(color: text),
                          ),
                        );
                      }
                      final notifications = snapshot.data ?? [];
                      if (notifications.isEmpty) {
                        return _buildEmptyState(isDark, text, muted, loc);
                      }

                      return ListView.separated(
                        itemCount: notifications.length,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          return _buildNotificationTile(
                             notif,
                             isDark,
                             text,
                             muted,
                             accent,
                             loc,
                           );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color text, Color muted, AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: muted.withValues(alpha: 0.08),
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
              loc.notificationsEmptyTitle,
              style: TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.notificationsEmptySubtitle,
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
    AppLocalizations loc,
  ) {
    final isFake = notif.prediction.toUpperCase() == 'FAKE';
    final statusColor = isFake ? VFColors.red600 : VFColors.emerald600;
    final statusBg = isFake ? VFColors.red50 : VFColors.emerald50;
    final statusBgDark = isFake
        ? VFColors.red600.withValues(alpha: 0.15)
        : VFColors.emerald600.withValues(alpha: 0.15);
    final scorePct = notif.score.toStringAsFixed(1);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: ValueKey(notif.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _removeNotification(notif.id, notif),
        confirmDismiss: (direction) async => await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final loc = AppLocalizations.of(ctx)!;
            return AlertDialog(
              title: Text(loc.notificationsDeleteTitle),
              content: Text(
                loc.notificationsDeleteMessage,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(loc.verifyCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: VFColors.red600),
                  child: Text(loc.notificationsDeleteConfirm),
                ),
              ],
            );
          },
        ),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: VFColors.red600.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: VFColors.red600,
            size: 24,
          ),
        ),
        child: GestureDetector(
          onTap: () async {
            if (!notif.isRead && _uid != null) {
              await NotificationService.instance.markAsRead(_uid, notif.id);
            }
          },
          child: Container(
          decoration: BoxDecoration(
            color: VFColors.adaptiveCard(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? VFColors.gray800 : VFColors.gray200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusIcon(
                  isFake: isFake,
                  isDark: isDark,
                  statusColor: statusColor,
                  statusBg: statusBg,
                  statusBgDark: statusBgDark,
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
                                fontWeight: notif.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                fontSize: 14,
                                color: text,
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: muted,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: _NotificationChip(
                                    label: isFake ? loc.verifyManipulatedLabel : loc.verifyAuthenticLabel,
                                    color: statusColor,
                                    bg: isDark ? statusBgDark : statusBg,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: _NotificationChip(
                                    label: '$scorePct% score',
                                    color: text,
                                    bg: isDark ? VFColors.gray800 : VFColors.gray100,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimeAgo(context, notif.createdAt),
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
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.isFake,
    required this.isDark,
    required this.statusColor,
    required this.statusBg,
    required this.statusBgDark,
  });

  final bool isFake;
  final bool isDark;
  final Color statusColor;
  final Color statusBg;
  final Color statusBgDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? statusBgDark : statusBg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isFake ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
        color: statusColor,
        size: 18,
      ),
    );
  }
}

class _NotificationChip extends StatelessWidget {
  const _NotificationChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
