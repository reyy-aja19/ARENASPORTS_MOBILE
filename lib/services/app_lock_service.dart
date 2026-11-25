import 'package:flutter/foundation.dart';

import 'pin_service.dart';
import 'session_service.dart';

/// Mengatur kapan aplikasi harus dikunci.
///
/// Kunci hanya aktif bila pengguna sudah login DAN mengaktifkan kunci aplikasi
/// dengan PIN. Verifikasi PIN/biometrik tidak pernah dikirim ke server.
class AppLockService extends ChangeNotifier {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  bool _locked = false;
  bool _initialized = false;
  DateTime? _pausedAt;
  bool _authenticationInProgress = false;

  bool get isLocked => _locked;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh(lockWhenEnabled: true);
  }

  /// Sinkronkan status kunci dengan sesi & pengaturan PIN saat ini.
  ///
  /// [lockWhenEnabled] hanya dipakai saat aplikasi baru dibuka. Perubahan
  /// pengaturan di dalam aplikasi tidak boleh langsung mengunci pengguna.
  Future<void> refresh({bool lockWhenEnabled = false}) async {
    var shouldLock = false;
    try {
      shouldLock = await SessionService.isLoggedIn() &&
          await PinService.instance.isLockEnabled();
    } catch (_) {
      shouldLock = false;
    }

    if (!shouldLock && _locked) {
      _locked = false;
      notifyListeners();
    }
    if (!_initialized) {
      _initialized = true;
    }

    // Cold start: bila kunci aktif, minta verifikasi sebelum masuk.
    if (lockWhenEnabled && shouldLock && !_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  void unlock() {
    if (!_locked) return;
    _locked = false;
    _pausedAt = null;
    notifyListeners();
  }

  void lockNow() {
    if (_locked) return;
    _locked = true;
    notifyListeners();
  }

  void handleAppPaused() {
    _pausedAt = DateTime.now();
  }

  Future<void> handleAppResumed() async {
    if (!_locked && _pausedAt != null && !_authenticationInProgress) {
      try {
        final enabled = await SessionService.isLoggedIn() &&
            await PinService.instance.isLockEnabled();
        if (enabled) {
          final timeout = await PinService.instance.lockTimeoutSeconds();
          final elapsed = DateTime.now().difference(_pausedAt!);
          final shouldLock = timeout == 0 || elapsed.inSeconds >= timeout;
          if (shouldLock) {
            _locked = true;
            notifyListeners();
          }
        }
      } catch (_) {
        // Jika status tidak dapat dibaca, jangan mengunci pengguna.
      }
    }
    _pausedAt = null;
  }

  /// Jalankan autentikasi biometrik tanpa memicu kunci otomatis saat sistem
  /// perangkat menampilkan dialog sidik jari / Face ID.
  Future<bool> authenticateBiometric({
    String reason = 'Verifikasi biometrik',
  }) async {
    _authenticationInProgress = true;
    try {
      return await PinService.instance.authenticate(reason: reason);
    } finally {
      _authenticationInProgress = false;
      _pausedAt = null;
    }
  }
}
