import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text("Kebijakan Privasi")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PrivacyIntro(),
              const SizedBox(height: 20),
              const _PrivacySection(
                icon: Icons.storage_outlined,
                title: 'Penyimpanan data',
                body: 'Data pengguna disimpan dengan aman.',
              ),
              const _PrivacySection(
                icon: Icons.share_outlined,
                title: 'Berbagi informasi',
                body: 'Kami tidak membagikan data ke pihak ketiga tanpa izin.',
              ),
              const _PrivacySection(
                icon: Icons.sports_tennis_outlined,
                title: 'Penggunaan data',
                body: 'Data hanya digunakan untuk layanan booking.',
              ),
              const _PrivacySection(
                icon: Icons.delete_outline,
                title: 'Penghapusan data',
                body: 'Pengguna dapat meminta penghapusan data kapan saja.',
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Dengan menggunakan aplikasi ini, Anda menyetujui kebijakan privasi ini.',
                  style: TextStyle(
                    color: Color(0xFF245B37),
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyIntro extends StatelessWidget {
  const _PrivacyIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF087F3C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: Colors.white, size: 28),
          SizedBox(height: 20),
          Text(
            'INFORMASI PENGGUNA',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Kebijakan Privasi',
            style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Kami menghargai privasi pengguna aplikasi ini.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF00A32A), size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text(body, style: TextStyle(color: Colors.grey.shade700, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}