import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veriframe_app/l10n/app_localizations.dart';

Future<void> deleteAccountAndNavigate(BuildContext context, VoidCallback onConfirm) async {
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
  onConfirm();
}

class DeleteAccountDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteAccountDialog({super.key, required this.onConfirm});

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
          onPressed: () => Navigator.pop(context),
          child: Text(loc.verifyCancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            deleteAccountAndNavigate(context, onConfirm);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(loc.deletePermanently),
        ),
      ],
    );
  }
}
