import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> requireAuthenticatedUser(
  BuildContext context, {
  String message = 'Silakan login dengan akun untuk melanjutkan booking.',
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token != null && token.isNotEmpty) return true;
  if (!context.mounted) return false;

  final shouldLogin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Login diperlukan'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Nanti'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Login'),
        ),
      ],
    ),
  );

  if (shouldLogin == true && context.mounted) {
    Navigator.pushNamed(context, '/login');
  }
  return false;
}