import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_navigator.dart';
import '../services/api_client.dart';
import '../services/app_lock_service.dart';
import '../services/auth_api.dart';
import '../services/pin_service.dart';
import '../services/session_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const _green = Color(0xFF00A32A);
  static const _darkGreen = Color(0xFF073B31);

  final PinService _pinService = PinService.instance;

  String _pin = '';
  bool _checking = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _autoBiometricRequested = false;
  String? _error;
  String _name = '';
  DateTime? _lockedUntil;
  Timer? _lockoutTicker;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    final user = await SessionService.currentUser();
    final biometricEnabled = await _pinService.isBiometricEnabled();
    final canUse = biometricEnabled
        ? await _pinService.canUseBiometrics()
        : false;
    if (!mounted) return;
    setState(() {
      _name = (user?['name'] ?? '').toString().trim();
      _biometricEnabled = biometricEnabled;
      _biometricAvailable = canUse;
    });

    if (biometricEnabled && canUse && !_autoBiometricRequested) {
      _autoBiometricRequested = true;
      _unlockWithBiometrics();
    }
  }

  bool get _isLockedOut =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  int get _lockoutSecondsLeft {
    final until = _lockedUntil;
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _onDigit(String digit) {
    if (_checking || _isLockedOut || _pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 6) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_checking || _isLockedOut || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submitPin() async {
    if (_checking || _isLockedOut) return;
    if (_pin.length < 4) {
      setState(() => _error = 'PIN minimal 4 digit.');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final result = await _pinService.verifyPin(_pin);
      if (!mounted) return;

      switch (result.status) {
        case PinVerifyStatus.success:
          AppLockService.instance.unlock();
          return;
        case PinVerifyStatus.notSet:
          // PIN hilang (misalnya data aplikasi dibersihkan sebagian).
          AppLockService.instance.unlock();
          return;
        case PinVerifyStatus.lockedOut:
          _startLockout(result.retryAfter);
          setState(() {
            _pin = '';
            _error =
                'Terlalu banyak percobaan. Tunggu ${result.retryAfter.inSeconds} detik.';
          });
          return;
        case PinVerifyStatus.incorrect:
          setState(() {
            _pin = '';
            _error = result.attemptsLeft > 0
                ? 'PIN salah. Sisa ${result.attemptsLeft} percobaan.'
                : 'PIN salah. Coba lagi.';
          });
          return;
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _startLockout(Duration duration) {
    _lockoutTicker?.cancel();
    _lockedUntil = DateTime.now().add(duration);
    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isLockedOut) {
        timer.cancel();
        setState(() {
          _lockedUntil = null;
          _error = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _unlockWithBiometrics() async {
    if (_checking) return;
    final ok = await AppLockService.instance.authenticateBiometric(
      reason: 'Buka kunci ARENASPORTS',
    );
    if (!mounted) return;
    if (ok) {
      AppLockService.instance.unlock();
    } else if (_error == null) {
      setState(() => _error = 'Verifikasi biometrik gagal. Gunakan PIN.');
    }
  }

  Future<void> _showForgotPin() async {
    if (_checking) return;

    final user = await SessionService.currentUser();
    final identifier = (user?['email'] ?? user?['phone'] ?? '')
        .toString()
        .trim();

    if (!mounted) return;

    if (identifier.isEmpty) {
      await _confirmLogout();
      return;
    }

    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lupa PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verifikasi dengan password akun Anda untuk membuat PIN baru. '
              'Data biometrik akan dinonaktifkan saat PIN direset.',
            ),
            const SizedBox(height: 14),
            Text(
              identifier,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password akun',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, '__logout__');
            },
            child: const Text('Keluar & login ulang'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, passwordController.text),
            child: const Text('Verifikasi'),
          ),
        ],
      ),
    );
    passwordController.dispose();

    if (password == '__logout__') {
      await _confirmLogout();
      return;
    }
    if (password == null || password.isEmpty) return;

    setState(() => _checking = true);
    try {
      await AuthApi.login(identifier: identifier, password: password);
      await _pinService.clearAll();
      if (!mounted) return;

      final newPin = await _askNewPin();
      if (newPin == null) {
        AppLockService.instance.unlock();
        return;
      }
      await _pinService.setPin(newPin);
      await _pinService.setLockEnabled(true);
      AppLockService.instance.unlock();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN baru berhasil dibuat.'),
          backgroundColor: _green,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal memverifikasi password: $e');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<String?> _askNewPin() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? dialogError;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Buat PIN Baru'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'PIN baru (4-6 digit)',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi PIN',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (pin.length < 4 || pin.length > 6) {
                    setDialogState(
                      () => dialogError = 'PIN harus 4-6 digit.',
                    );
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(
                      () => dialogError = 'Konfirmasi PIN tidak sama.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, pin);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );

    pinController.dispose();
    confirmController.dispose();
    return result;
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar & Login Ulang'),
        content: const Text(
          'PIN dan biometrik akan dihapus. Anda perlu login kembali untuk '
          'membuat PIN baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _checking = true);
    try {
      await AuthApi.logout();
    } finally {
      AppLockService.instance.unlock();
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockedOut = _isLockedOut;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _darkGreen,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF166534), _darkGreen],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/arenasports_icon.png',
                        width: 118,
                        height: 56,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 18),
                      const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFA5EFBF),
                        size: 30,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Aplikasi Terkunci',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _name.isEmpty
                            ? 'Masukkan PIN untuk melanjutkan'
                            : 'Halo $_name, masukkan PIN untuk melanjutkan',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      _pinDots(),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 20,
                        child: Text(
                          lockedOut
                              ? 'Tunggu $_lockoutSecondsLeft detik lagi.'
                              : (_error ?? ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: lockedOut
                                ? const Color(0xFFFFD166)
                                : const Color(0xFFFFA8A8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _keypad(enabled: !lockedOut && !_checking),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              (_checking || lockedOut || _pin.length < 4)
                              ? null
                              : _submitPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white24,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _checking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'BUKA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                      if (_biometricEnabled && _biometricAvailable) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _checking
                              ? null
                              : _unlockWithBiometrics,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Buka dengan Biometrik'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFA5EFBF),
                            side: const BorderSide(color: Color(0xFF54E28C)),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _checking ? null : _showForgotPin,
                        child: const Text(
                          'Lupa PIN?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinDots() {
    final visibleLength = _pin.length < 4 ? 4 : _pin.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(visibleLength, (index) {
        final filled = index < _pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? const Color(0xFF54E28C) : Colors.transparent,
            border: Border.all(
              color: filled ? const Color(0xFF54E28C) : Colors.white38,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _keypad({required bool enabled}) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var column = 0; column < 3; column++)
                _keyButton(keys[row * 3 + column], enabled: enabled),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 84, height: 66),
            _keyButton('0', enabled: enabled),
            SizedBox(
              width: 84,
              height: 66,
              child: Center(
                child: IconButton(
                  onPressed: enabled ? _onBackspace : null,
                  icon: const Icon(
                    Icons.backspace_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyButton(String digit, {required bool enabled}) {
    return SizedBox(
      width: 84,
      height: 66,
      child: Center(
        child: InkWell(
          onTap: enabled ? () => _onDigit(digit) : null,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.03),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              digit,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
