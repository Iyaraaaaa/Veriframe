import 'package:flutter/material.dart';
import 'package:veriframe_app/widgets/global_app_bar.dart';

/// Standard page shell used by all main screens.
///
/// Wraps page content with the shared [globalAppBar] so the app bar (logo,
/// title, language picker, theme toggle) stays visible and identical on every
/// screen while only the [body] changes. The drawer, bottom navigation bar and
/// floating action button are optional so each page can opt in.
class MainScaffold extends StatelessWidget {
  final Widget body;
  final bool showBack;
  final Widget? drawer;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final List<Widget>? extraActions;
  final Widget? title;
  final PreferredSizeWidget? appBar;

  const MainScaffold({
    super.key,
    required this.body,
    this.showBack = false,
    this.drawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extraActions,
    this.title,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ??
          globalAppBar(
            context,
            showBack: showBack,
            extraActions: extraActions,
            title: title,
          ),
      drawer: drawer,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
