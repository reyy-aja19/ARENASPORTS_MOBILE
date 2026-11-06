import 'dart:ui';

import 'package:flutter/material.dart';

class GuestAccessOverlay extends StatelessWidget {
  final bool isGuest;
  final Widget child;
  final String message;

  const GuestAccessOverlay({
    super.key,
    required this.isGuest,
    required this.child,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!isGuest) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: IgnorePointer(child: child),
        ),
        ColoredBox(color: Colors.white.withValues(alpha: 0.45)),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 36, color: Color(0xFF00A32A)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Daftar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}