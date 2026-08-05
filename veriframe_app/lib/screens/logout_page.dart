import 'package:flutter/material.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/widgets/main_scaffold.dart';

class LogoutPage extends StatelessWidget {
  const LogoutPage({super.key});

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.logoutConfirmTitle),
        content: Text(AppLocalizations.of(context)!.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: Text(AppLocalizations.of(context)!.logoutCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, '/login'); // Navigate to login
            },
            child: Text(AppLocalizations.of(context)!.logoutButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      showBack: true,
      title: Text(AppLocalizations.of(context)!.logoutButton),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: Text(AppLocalizations.of(context)!.logoutButton),
          onPressed: () => _confirmLogout(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}



