import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_api.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final oldPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isSaving = false;

  @override
  void dispose() {
    oldPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (oldPassword.text.isEmpty) {
      _showSnackBar('Password lama wajib diisi.', Colors.red);
      return;
    }
    if (newPassword.text.length < 8) {
      _showSnackBar('Password baru minimal 8 karakter.', Colors.red);
      return;
    }
    if (newPassword.text != confirmPassword.text) {
      _showSnackBar('Konfirmasi password tidak cocok.', Colors.red);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AuthApi.changePassword(
        currentPassword: oldPassword.text,
        password: newPassword.text,
      );
      if (!mounted) return;
      _showSnackBar('Password berhasil diubah.', const Color(0xFF00A32A));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        e is ApiException ? e.message : 'Gagal mengubah password: $e',
        Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text("Ubah Password")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF00A32A),
                      size: 26,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jaga akun tetap aman',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Gunakan password yang kuat dan jangan bagikan kepada siapa pun.',
                            style: TextStyle(
                              color: Color(0xFF53635A),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Perbarui password',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Masukkan password saat ini, lalu buat password baru minimal 8 karakter.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _passwordField(
                      controller: oldPassword,
                      label: 'Password Lama',
                      visible: _showOldPassword,
                      onToggle: () =>
                          setState(() => _showOldPassword = !_showOldPassword),
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      controller: newPassword,
                      label: 'Password Baru',
                      visible: _showNewPassword,
                      onToggle: () =>
                          setState(() => _showNewPassword = !_showNewPassword),
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      controller: confirmPassword,
                      label: 'Konfirmasi Password Baru',
                      visible: _showConfirmPassword,
                      onToggle: () => setState(
                        () => _showConfirmPassword = !_showConfirmPassword,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : submit,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_reset),
                        label: Text(
                          _isSaving ? 'Menyimpan...' : 'Simpan Password',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A32A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: visible ? 'Sembunyikan password' : 'Tampilkan password',
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
