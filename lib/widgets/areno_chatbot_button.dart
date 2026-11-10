import 'package:flutter/material.dart';

import '../widgets/areno_logo.dart';
import '../screens/chatbot_screen.dart';

/// Tombol floating Areno (logo robot) di kanan bawah setiap halaman,
/// di atas bottom navigation bar.
class ArenoChatbotButton extends StatelessWidget {
  const ArenoChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
          );
        },
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const ArenoLogo(size: 76, animate: true),
        ),
      ),
    );
  }
}
