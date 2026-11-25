import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum PinVerifyStatus { success, incorrect, lockedOut, notSet }

class PinVerifyResult {
  const PinVerifyResult(
    this.status, {
    this.attemptsLeft = 0,
    this.retryAfter = Duration.zero,
  });

  final PinVerifyStatus status;
  final int attemptsLeft;
  final Duration retryAfter;

  bool get isSuccess => status == PinVerifyStatus.success;
}

/// Menyimpan PIN aplikasi secara aman.
///
/// PIN tidak pernah disimpan dalam bentuk asli. Yang disimpan hanyalah hash
/// PBKDF2-HMAC-SHA256 dengan salt acak di penyimpanan terenkripsi perangkat
/// (Android Keystore / iOS Keychain).
///
/// Data biometrik tidak pernah disimpan atau dikirim ke server. Verifikasi
/// sidik jari / Face ID sepenuhnya dilakukan oleh sistem keamanan perangkat
/// melalui [LocalAuthentication].
class PinService {
  PinService._();

  static final PinService instance = PinService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _pinHashKey = 'user_pin_hash_v2';
  static const _pinSaltKey = 'user_pin_salt';
  static const _pinIterationsKey = 'user_pin_iterations';
  static const _legacyPinHashKey = 'user_pin_hash';
  static const _failedAttemptsKey = 'pin_failed_attempts';
  static const _lockedUntilKey = 'pin_locked_until';
  static const _lockEnabledKey = 'app_lock_enabled';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _lockTimeoutKey = 'app_lock_timeout_seconds';

  static const int _defaultIterations = 80000;
  static const int _saltLength = 16;
  static const int _hashLength = 32;
  static const int _maxAttemptsBeforeDelay = 5;

  /// Batas waktu default: 1 menit setelah aplikasi ditinggalkan.
  static const int defaultLockTimeoutSeconds = 60;

  final LocalAuthentication _localAuth = LocalAuthentication();

  // ---------------------------------------------------------------------------
  // PIN
  // ---------------------------------------------------------------------------

  Future<bool> hasPin() async {
    final hash = await _storage.read(key: _pinHashKey);
    if (hash != null && hash.isNotEmpty) return true;
    final legacy = await _storage.read(key: _legacyPinHashKey);
    return legacy != null && legacy.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(_saltLength);
    final iterations = _defaultIterations;
    final hash = await _deriveHash(
      pin: pin,
      salt: salt,
      iterations: iterations,
    );

    await _storage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _storage.write(key: _pinIterationsKey, value: '$iterations');
    await _storage.write(key: _pinHashKey, value: base64Encode(hash));
    await _storage.delete(key: _legacyPinHashKey);
    await _resetAttempts();
  }

  Future<PinVerifyResult> verifyPin(String pin) async {
    final hashRecord = await _storage.read(key: _pinHashKey);
    if (hashRecord == null || hashRecord.isEmpty) {
      return _verifyLegacyPin(pin);
    }

    final lockedFor = await _lockRemaining();
    if (lockedFor > Duration.zero) {
      return PinVerifyResult(
        PinVerifyStatus.lockedOut,
        retryAfter: lockedFor,
      );
    }

    final saltRecord = await _storage.read(key: _pinSaltKey);
    final iterationsRecord = await _storage.read(key: _pinIterationsKey);
    final salt = _decode(saltRecord);
    final iterations = int.tryParse(iterationsRecord ?? '') ?? _defaultIterations;
    final expected = _decode(hashRecord);
    if (salt == null || expected == null) {
      return const PinVerifyResult(PinVerifyStatus.notSet);
    }

    final actual = await _deriveHash(
      pin: pin,
      salt: salt,
      iterations: iterations,
    );
    if (_constantTimeEquals(actual, expected)) {
      await _resetAttempts();
      return const PinVerifyResult(PinVerifyStatus.success);
    }

    return _registerFailedAttempt();
  }

  Future<PinVerifyResult> _verifyLegacyPin(String pin) async {
    final legacy = await _storage.read(key: _legacyPinHashKey);
    if (legacy == null || legacy.isEmpty) {
      return const PinVerifyResult(PinVerifyStatus.notSet);
    }

    final lockedFor = await _lockRemaining();
    if (lockedFor > Duration.zero) {
      return PinVerifyResult(
        PinVerifyStatus.lockedOut,
        retryAfter: lockedFor,
      );
    }

    final candidate = sha256
        .convert(utf8.encode('arenasports_pin::$pin'))
        .toString();
    if (!_constantTimeEquals(utf8.encode(candidate), utf8.encode(legacy))) {
      return _registerFailedAttempt();
    }

    // Upgrade otomatis hash lama ke PBKDF2 setelah PIN lama terbukti benar.
    await setPin(pin);
    return const PinVerifyResult(PinVerifyStatus.success);
  }

  Future<PinVerifyResult> _registerFailedAttempt() async {
    final raw = await _storage.read(key: _failedAttemptsKey);
    final attempts = (int.tryParse(raw ?? '') ?? 0) + 1;
    await _storage.write(key: _failedAttemptsKey, value: '$attempts');

    if (attempts < _maxAttemptsBeforeDelay) {
      return PinVerifyResult(
        PinVerifyStatus.incorrect,
        attemptsLeft: _maxAttemptsBeforeDelay - attempts,
      );
    }

    final delaySeconds = _delayForAttempts(attempts);
    final until = DateTime.now()
        .add(Duration(seconds: delaySeconds))
        .millisecondsSinceEpoch;
    await _storage.write(key: _lockedUntilKey, value: '$until');
    return PinVerifyResult(
      PinVerifyStatus.lockedOut,
      retryAfter: Duration(seconds: delaySeconds),
    );
  }

  int _delayForAttempts(int attempts) {
    if (attempts <= 5) return 30;
    if (attempts == 6) return 60;
    if (attempts == 7) return 120;
    return 300;
  }

  Future<Duration> _lockRemaining() async {
    final raw = await _storage.read(key: _lockedUntilKey);
    final until = int.tryParse(raw ?? '');
    if (until == null) return Duration.zero;
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  Future<void> _resetAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockedUntilKey);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinIterationsKey);
    await _storage.delete(key: _legacyPinHashKey);
    await _resetAttempts();
  }

  /// Menghapus PIN sekaligus seluruh pengaturan kunci aplikasi.
  Future<void> clearAll() async {
    await clearPin();
    await _storage.delete(key: _lockEnabledKey);
    await _storage.delete(key: _biometricEnabledKey);
    await _storage.delete(key: _lockTimeoutKey);
  }

  // ---------------------------------------------------------------------------
  // Kunci aplikasi
  // ---------------------------------------------------------------------------

  Future<bool> isLockEnabled() async {
    final enabled = await _storage.read(key: _lockEnabledKey);
    if (enabled != 'true') return false;
    return hasPin();
  }

  Future<void> setLockEnabled(bool enabled) async {
    if (enabled) {
      await _storage.write(key: _lockEnabledKey, value: 'true');
      return;
    }
    await _storage.write(key: _lockEnabledKey, value: 'false');
    await _storage.delete(key: _biometricEnabledKey);
  }

  Future<int> lockTimeoutSeconds() async {
    final raw = await _storage.read(key: _lockTimeoutKey);
    final value = int.tryParse(raw ?? '');
    if (value == null || value < 0) return defaultLockTimeoutSeconds;
    return value;
  }

  Future<void> setLockTimeoutSeconds(int seconds) async {
    await _storage.write(key: _lockTimeoutKey, value: '$seconds');
  }

  // ---------------------------------------------------------------------------
  // Biometrik (diverifikasi oleh sistem keamanan perangkat)
  // ---------------------------------------------------------------------------

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    if (value != 'true') return false;
    return hasPin();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled && !await hasPin()) {
      throw StateError('Buat PIN terlebih dahulu sebelum mengaktifkan biometrik.');
    }
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String reason = 'Verifikasi biometrik',
    bool biometricOnly = true,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helper kriptografi
  // ---------------------------------------------------------------------------

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  List<int>? _decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<List<int>> _deriveHash({
    required String pin,
    required List<int> salt,
    required int iterations,
  }) {
    return compute(
      _derivePinHash,
      _Pbkdf2Params(pin: pin, salt: salt, iterations: iterations),
    );
  }
}

class _Pbkdf2Params {
  const _Pbkdf2Params({
    required this.pin,
    required this.salt,
    required this.iterations,
  });

  final String pin;
  final List<int> salt;
  final int iterations;
}

List<int> _derivePinHash(_Pbkdf2Params params) {
  final hmac = Hmac(sha256, utf8.encode(params.pin));
  final blockCount =
      (PinService._hashLength / 32.0).ceil();
  final output = <int>[];

  for (var block = 1; block <= blockCount; block++) {
    final blockSalt = <int>[
      ...params.salt,
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];

    var u = hmac.convert(blockSalt).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < params.iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    output.addAll(t);
  }

  return output.sublist(0, PinService._hashLength);
}
