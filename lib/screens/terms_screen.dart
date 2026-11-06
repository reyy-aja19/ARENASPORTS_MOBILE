import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text("Syarat & Ketentuan")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegalIntro(
                icon: Icons.description_outlined,
                eyebrow: 'INFORMASI PENGGUNA',
                title: 'Syarat & Ketentuan',
                description: 'Ketentuan penggunaan layanan penyewaan lapangan.',
              ),
              const SizedBox(height: 20),
              const _LegalSection(
                number: '01',
                title: 'Penggunaan aplikasi',
                body: 'Pengguna wajib menggunakan aplikasi dengan itikad baik.',
              ),
              const _LegalSection(
                number: '02',
                title: 'Layanan booking',
                body: 'Dilarang menyalahgunakan layanan booking lapangan.',
              ),
              const _LegalSection(
                number: '03',
                title: 'Transaksi',
                body: 'Semua transaksi mengikuti kebijakan platform.',
              ),
              const _LegalSection(
                number: '04',
                title: 'Perubahan ketentuan',
                body: 'Pihak pengelola berhak mengubah ketentuan sewaktu-waktu.',
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
                  'Dengan menggunakan aplikasi ini, Anda dianggap menyetujui semua syarat di atas.',
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

class _LegalIntro extends StatelessWidget {
  const _LegalIntro({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF087F3C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 20),
          Text(
            eyebrow,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(color: Colors.white70, height: 1.4)),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
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
          Text(
            number,
            style: const TextStyle(color: Color(0xFF00A32A), fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 14),
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