import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veriframe_app/controllers/settings_controller.dart';
import 'package:veriframe_app/service/notification_service.dart';
import 'package:veriframe_app/utils/theme.dart';

class HomeTopBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeTopBar({
    super.key,
    this.showBack = false,
    this.onNotificationTap,
    this.title,
  });

  final bool showBack;
  final VoidCallback? onNotificationTap;
  final Widget? title;

  static const _kHeight = kToolbarHeight;

  @override
  Size get preferredSize => const Size.fromHeight(_kHeight);

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final languages = const [
      _AppLanguage('English', 'en', '🇺🇸'),
      _AppLanguage('සිංහල', 'si', '🇱🇰'),
      _AppLanguage('தமிழ்', 'ta', '🇮🇳'),
    ];

    return AppBar(
      automaticallyImplyLeading: !showBack,
      leading: showBack
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: scheme.onPrimary),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            )
          : null,
      title: title ??
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shield, color: scheme.onPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'VERIFRAME',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: scheme.onPrimary),
      actions: [
        if (onNotificationTap != null)
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              final uid = authSnapshot.data?.uid ?? FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) {
                return IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: onNotificationTap,
                  tooltip: 'Notifications',
                );
              }
              return StreamBuilder<int>(
                stream: NotificationService.instance.getUnreadCountStream(uid),
                builder: (context, countSnapshot) {
                  final count = countSnapshot.data ?? 0;
                  final badgeText = count > 99 ? '99+' : '$count';
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                        onPressed: onNotificationTap,
                        tooltip: 'Notifications',
                      ),
                      if (count > 0)
                        Positioned(
                          right: 8,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        PopupMenuButton<Locale>(
          icon: Icon(Icons.language, color: scheme.onPrimary),
          tooltip: 'Change Language',
          onSelected: (locale) => controller.setLocale(locale),
          itemBuilder: (_) => languages
              .map(
                (l) => PopupMenuItem<Locale>(
                  value: Locale(l.code),
                  child: Row(
                    children: [
                      Text(l.flag),
                      const SizedBox(width: 8),
                      Text(l.name),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        IconButton(
          icon: Icon(
            isDark ? Icons.wb_sunny : Icons.nightlight_round,
            color: isDark ? VFColors.amber600 : scheme.onPrimary,
          ),
          onPressed: () => controller.toggleTheme(),
          tooltip: isDark ? 'Light Mode' : 'Dark Mode',
        ),
      ],
    );
  }
}

class _AppLanguage {
  final String name;
  final String code;
  final String flag;
  const _AppLanguage(this.name, this.code, this.flag);
}
