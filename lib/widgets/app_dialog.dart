import 'package:flutter/material.dart';

/// Warna aksen utama aplikasi (hijau ARENASPORTS).
const Color kDialogAccent = Color(0xFF00A32A);

/// Warna aksen untuk aksi berbahaya (hapus, keluar, batal permanen).
const Color kDialogDanger = Color(0xFFE53935);

/// Kerangka dialog dengan gaya seragam ARENASPORTS.
///
/// Dipakai oleh [showAppConfirmDialog], [showAppInfoDialog], dan bisa juga
/// dipakai langsung untuk dialog dengan konten kustom.
class AppDialogShell extends StatelessWidget {
  final IconData? icon;
  final Color accent;
  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  const AppDialogShell({
    super.key,
    this.icon,
    this.accent = kDialogAccent,
    required this.title,
    this.message,
    this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 32),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2A2B),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              if (content != null) ...[const SizedBox(height: 18), content!],
              const SizedBox(height: 22),
              Row(children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog konfirmasi (dua tombol: batal & aksi utama).
///
/// Mengembalikan `true` jika user menekan tombol utama.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Batal',
  IconData icon = Icons.help_outline_rounded,
  Color accent = kDialogAccent,
  bool destructive = false,
}) async {
  final color = destructive ? kDialogDanger : accent;

  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) => AppDialogShell(
      icon: icon,
      accent: color,
      title: title,
      message: message,
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Dialog informasi dengan satu tombol.
Future<void> showAppInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'Mengerti',
  IconData icon = Icons.info_outline_rounded,
  Color accent = kDialogAccent,
  Widget? content,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) => AppDialogShell(
      icon: icon,
      accent: accent,
      title: title,
      message: message,
      content: content,
      actions: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Dialog loading dengan gaya aplikasi (tidak bisa ditutup dengan tap).
Future<void> showAppLoadingDialog(
  BuildContext context, {
  String message = 'Memproses...',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: kDialogAccent,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
