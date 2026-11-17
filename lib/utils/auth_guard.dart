import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../widgets/app_dialog.dart';

Future<bool> requireAuthenticatedUser(
  BuildContext context, {
  String message = 'Silakan login dengan akun untuk melanjutkan booking.',
}) async {
  if (await SessionService.isLoggedIn()) return true;
  if (!context.mounted) return false;

  final shouldLogin = await showAppConfirmDialog(
    context,
    title: 'Login Diperlukan',
    message: message,
    icon: Icons.lock_outline_rounded,
    confirmLabel: 'Login',
    cancelLabel: 'Nanti',
  );

  if (shouldLogin && context.mounted) {
    Navigator.pushNamed(context, '/login');
  }
  return false;
}
