import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:veriframe_app/models/notification_model.dart';
import 'package:veriframe_app/utils/navigator_key.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          // Tap action opens Verification History
          navigatorKey.currentState?.pushNamed('/reports');
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Init error: $e');
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init(); // Ensure it is initialized

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'veriframe_channel',
      'VeriFrame Notifications',
      channelDescription: 'Verification completed notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _localNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Failed to show notification: $e');
    }
  }

  // --- FIRESTORE OPERATION INTERFACES ---

  Stream<List<NotificationModel>> getNotificationsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<int> getUnreadCountStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final count = snapshot.docs.length;
          updateAppBadge(count);
          return count;
        });
  }

  Future<void> updateAppBadge(int count) async {
    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (isSupported) {
        if (count > 0) {
          await FlutterAppBadger.updateBadgeCount(count);
        } else {
          await FlutterAppBadger.removeBadge();
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error updating app badge: $e');
    }
  }

  Future<void> markAsRead(String uid, String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('[NotificationService] Error marking read: $e');
    }
  }

  Future<void> markAllAsRead(String uid) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final docs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      for (final doc in docs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[NotificationService] Error marking all read: $e');
    }
  }

  Future<void> createNotification(String uid, NotificationModel notification) async {
    int retries = 3;
    while (retries > 0) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(notification.id)
            .set(notification.toMap());
        break;
      } catch (e) {
        retries--;
        if (retries == 0) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> refreshBadge(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();
      await updateAppBadge(snapshot.docs.length);
    } catch (e) {
      debugPrint('[NotificationService] Error refreshing badge: $e');
    }
  }

  Future<void> deleteNotification(String uid, String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('[NotificationService] Error deleting notification: $e');
    }
  }

  Future<void> deleteAllNotifications(String uid) async {
    try {
      const batchLimit = 500;
      while (true) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .limit(batchLimit)
            .get();
        if (snapshot.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < batchLimit) break;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error deleting all notifications: $e');
      rethrow;
    }
  }

  /// Cancels all displayed/pending local (system-tray) notifications and
  /// clears the app badge. Call this when the user deletes their account.
  Future<void> cancelAllLocalNotifications() async {
    try {
      await init();
      await _localNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] Error cancelling local notifications: $e');
    }
    await updateAppBadge(0);
  }
}
