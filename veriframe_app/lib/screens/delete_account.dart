import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';
import 'package:veriframe_app/service/user_service.dart';
import 'package:veriframe_app/utils/navigator_key.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _closeAndNavigateToLogin();
      return;
    }

    setState(() => _isDeleting = true);

    try {
      await UserService.deleteUser(user.uid);
      _showSnackBar(loc.accountDeleted, Colors.green);
      await Future.delayed(const Duration(milliseconds: 1200));
      _closeAndNavigateToLogin();
    } on FirebaseAuthException catch (e) {
      debugPrint('Delete account error: $e');
      _showSnackBar(_errorMessage(e.code), Colors.red);
      if (mounted) setState(() => _isDeleting = false);
    } catch (e) {
      debugPrint('Delete account error: $e');
      _showSnackBar('Failed to delete account. Please try again.', Colors.red);
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String _errorMessage(String code) {
    switch (code) {
      case 'requires-recent-login':
        return 'Please sign in again to delete your account.';
      case 'user-token-expired':
        return 'Session expired. Please sign in again.';
      case 'user-not-found':
        return 'Account not found.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Failed to delete account. Please try again.';
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _closeAndNavigateToLogin() {
    if (!mounted) return;
    // Clear any lingering snack bars before closing the dialog
    ScaffoldMessenger.of(context).clearSnackBars();
    // Pop the dialog
    Navigator.pop(context);
    // Use the global navigator key to push to /login and remove all routes,
    // so we never reference the now-deactivated dialog context.
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        loc.deleteAccountTitle,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      content: Text(
        loc.deleteAccountMessage,
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text(loc.verifyCancel),
        ),
        ElevatedButton(
          onPressed: _isDeleting ? null : _deleteAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isDeleting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(loc.deletePermanently),
        ),
      ],
    );
  }
}
