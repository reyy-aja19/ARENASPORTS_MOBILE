import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/api_client.dart';
import '../services/auth_api.dart';
import '../widgets/slider_captcha.dart';
import '../widgets/turnstile_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isLoading = false;

  bool _captchaVerified = false;

  Future<void> _handleRegister() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirm = _confirmController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showSnackBar(
        "Semua kolom (termasuk nomor HP) wajib diisi!",
        Colors.orange,
      );
      return;
    }

    if (!email.contains('@')) {
      _showSnackBar("Masukkan email yang valid.", Colors.orange);
      return;
    }

    if (password.length < 8) {
      _showSnackBar("Password minimal 8 karakter!", Colors.orange);
      return;
    }

    if (password != confirm) {
      _showSnackBar("Konfirmasi password tidak sama.", Colors.orange);
      return;
    }

    if (!_captchaVerified) {
      _showSnackBar(
        "Selesaikan verifikasi puzzle terlebih dahulu.",
        Colors.orange,
      );
      return;
    }

    // Selesaikan verifikasi CAPTCHA (Cloudflare Turnstile) — sama seperti web.
    final turnstileToken = await showTurnstileDialog(
      context: context,
      title: 'Verifikasi CAPTCHA',
    );
    if (turnstileToken == null) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      await AuthApi.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        turnstileToken: turnstileToken,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/success_auth');
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      _showSnackBar("Gagal mendaftar: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- BUILD: background gradasi + card putih bersih ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF166534), Color(0xFF052E1A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/arenasports_icon.png',
                        width: 140,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ARENASPORTS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'FIND YOUR GAME',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFA5EFBF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F2D1F),
            offset: Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BUAT AKUN BARU',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: Color(0xFF2F855A),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Daftar ArenaSports',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2A2B),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Buat akun dan mulai pengalaman olahraga yang lebih mudah.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 26),
          _styledField(
            label: 'Nama Lengkap',
            controller: _nameController,
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          _styledField(
            label: 'Email',
            controller: _emailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _styledField(
            label: 'Nomor HP',
            controller: _phoneController,
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _styledField(
            label: 'Password (minimal 8 karakter)',
            controller: _passwordController,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
          const SizedBox(height: 14),
          _styledField(
            label: 'Konfirmasi Password',
            controller: _confirmController,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
          const SizedBox(height: 16),
          // Puzzle captcha milik mobile (tetap dipakai, ditambahkan Turnstile
          // Cloudflare sejalan dengan web).
          SliderCaptcha(
            onVerificationChanged: (verified) =>
                setState(() => _captchaVerified = verified),
          ),
          const SizedBox(height: 20),
          _primaryButton(
            label: 'KONFIRMASI',
            onPressed: _handleRegister,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'atau daftar dengan',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _googleButton(),
          const SizedBox(height: 10),
          _appleButton(),
          const SizedBox(height: 10),
          _whatsAppButton(),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Sudah punya akun? ',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Masuk',
                  style: TextStyle(
                    color: Color(0xFF00A32A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _styledField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Color(0xFF1E2A2B),
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00A32A), width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00A32A),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _googleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleRegister,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: Colors.grey.shade300),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://img.icons8.com/color/48/000000/google-logo.png',
            height: 24,
            width: 24,
          ),
          const SizedBox(width: 10),
          const Text(
            'Daftar Dengan Google',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleAppleRegister,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: Color(0xFF111827)),
        backgroundColor: Colors.white,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apple, color: Colors.black, size: 24),
          SizedBox(width: 10),
          Text(
            'Daftar Dengan Apple',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whatsAppButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleWhatsAppRegister,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: Colors.green.shade300),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_rounded, color: Colors.green.shade700, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Daftar Dengan WhatsApp',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // --- DAFTAR GOOGLE ---
  Future<void> _handleGoogleRegister() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId:
            '844099394384-tk6tsrvnppuvuafu4eshqfhq2m1hl9eu.apps.googleusercontent.com',
      );
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final idToken = await userCredential.user?.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException('Token Google tidak tersedia.');
      }
      await AuthApi.loginWithGoogle(idToken);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      _showSnackBar("Gagal Daftar Google: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DAFTAR APPLE ---
  Future<void> _handleAppleRegister() async {
    if (!(Platform.isIOS || Platform.isMacOS || Platform.isAndroid)) {
      _showSnackBar('Login Apple tidak didukung di perangkat ini.', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const ApiException('Token Apple tidak tersedia. Coba lagi.');
      }

      final givenName = (credential.givenName ?? '').trim();
      final familyName = (credential.familyName ?? '').trim();
      final fullName = [givenName, familyName].where((e) => e.isNotEmpty).join(' ');

      await AuthApi.loginWithApple(
        identityToken: identityToken,
        authorizationCode: credential.authorizationCode,
        email: credential.email,
        name: fullName.isNotEmpty ? fullName : null,
      );

      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _showSnackBar('Gagal Daftar Apple: ${e.message}', Colors.red);
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      _showSnackBar('Gagal Daftar Apple: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DAFTAR VIA WHATSAPP (untuk tujuan register) ---
  Future<void> _handleWhatsAppRegister() async {
    // 1. Minta nomor HP
    final phoneController = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Daftar dengan WhatsApp'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Nomor WhatsApp',
            hintText: '081234567890',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, phoneController.text.trim()),
            child: const Text('Kirim OTP'),
          ),
        ],
      ),
    );
    phoneController.dispose();
    if (phone == null || phone.isEmpty) return;

    // 2. Selesaikan verifikasi CAPTCHA (Cloudflare Turnstile) — sama seperti web.
    if (!mounted) return;
    final turnstileToken = await showTurnstileDialog(
      context: context,
      title: 'Verifikasi CAPTCHA',
    );
    if (turnstileToken == null) return;
    if (!mounted) return;

    // 3. Minta OTP WhatsApp (untuk tujuan register)
    setState(() => _isLoading = true);
    final data = await AuthApi.requestWhatsAppOtp(
      phone: phone,
      purpose: 'register',
      name: _nameController.text.trim(),
      turnstileToken: turnstileToken,
    );
    final otpToken = data['otp_token']?.toString();
    if (otpToken == null || otpToken.isEmpty) {
      _showSnackBar('Kode OTP gagal dibuat oleh server.', Colors.red);
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 4. Masukkan kode OTP
    if (!mounted) return;
    final otpController = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verifikasi OTP'),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'Kode OTP 6 digit'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, otpController.text.trim()),
            child: const Text('Verifikasi'),
          ),
        ],
      ),
    );
    otpController.dispose();
    if (otp == null || otp.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await AuthApi.verifyWhatsAppOtp(otpToken: otpToken, otp: otp);
      if (mounted) Navigator.pushReplacementNamed(context, '/success_auth');
    } on ApiException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
