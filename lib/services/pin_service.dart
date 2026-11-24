import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PinService {
  PinService._();

  static final PinService instance = PinService._();

  static const _storage = FlutterSecureStorage();
  static const _pinHashKey = 'user_pin_hash';
  static const _biometricEnabledKey = 'biometric_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();

  String _hashPin(String pin) {
    final bytes = utf8.encode('arenasports_pin::$pin');
    return sha256.convert(bytes).toString();
  }

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinHashKey, value: _hashPin(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _storage.read(key: _pinHashKey);
    if (hash == null || hash.isEmpty) return false;
    return hash == _hashPin(pin);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Verifikasi biometrik'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
