import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _isDeleting = false;

  Future<void> _deleteAccountAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();
      }
    } catch (e) {
      debugPrint('Delete account error: $e');
    }
    await FirebaseAuth.instance.signOut();

    if (mounted) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.accountDeleted),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
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
          onPressed: _isDeleting
              ? null
              : () async {
                  setState(() => _isDeleting = true);
                  Navigator.pop(context);
                  await _deleteAccountAndNavigate();
                },
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
