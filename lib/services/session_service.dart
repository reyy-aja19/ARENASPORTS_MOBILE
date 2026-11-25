import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sumber tunggal data sesi pengguna.
///
/// Token akses disimpan di penyimpanan terenkripsi perangkat (Keystore/Keychain),
/// sedangkan data pengguna non-sensitif disimpan sebagai JSON di
/// SharedPreferences untuk kebutuhan tampilan cepat.
class SessionService {
  static const String tokenKey = 'token';
  static const String userKey = 'user';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String authModeKey = 'auth_mode';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Dipakai layar lain untuk memuat ulang data setelah sesi login/logout.
  static final ValueNotifier<int> authRevision = ValueNotifier<int>(0);

  /// Dipakai untuk memberi tahu perubahan data pengguna (poin, profil, dll).
  static final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<String?> token() async {
    try {
      final secureToken = await _secure.read(key: tokenKey);
      if (secureToken != null && secureToken.isNotEmpty) return secureToken;
    } catch (_) {
      // Fallback ke SharedPreferences bila secure storage tidak tersedia.
    }

    final prefs = await _prefs;
    final legacyToken = prefs.getString(tokenKey);
    if (legacyToken == null || legacyToken.isEmpty) return null;

    // Migrasi token lama dari SharedPreferences ke secure storage.
    try {
      await _secure.write(key: tokenKey, value: legacyToken);
      await prefs.remove(tokenKey);
    } catch (_) {
      // Biarkan token lama tetap dipakai bila migrasi gagal.
    }
    return legacyToken;
  }

  static Future<bool> isLoggedIn() async => (await token()) != null;

  static Future<Map<String, dynamic>?> currentUser() async {
    final prefs = await _prefs;
    final raw = prefs.getString(userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  static Future<int?> userId() async {
    final prefs = await _prefs;
    final id = prefs.getInt(userIdKey);
    if (id != null) return id;
    final user = await currentUser();
    return (user?['id'] as num?)?.toInt();
  }

  static Future<int> points() async {
    final user = await currentUser();
    return (user?['points'] as num?)?.toInt() ?? 0;
  }

  static Future<void> save({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    var storedSecurely = false;
    try {
      await _secure.write(key: tokenKey, value: token);
      storedSecurely = true;
    } catch (_) {
      // Penyimpanan terenkripsi gagal; token disimpan sebagai fallback.
    }
    final prefs = await _prefs;
    if (storedSecurely) {
      await prefs.remove(tokenKey);
    } else {
      await prefs.setString(tokenKey, token);
    }
    await prefs.setString(authModeKey, 'api');
    await _writeUser(prefs, user);
    authRevision.value++;
    dataRevision.value++;
  }

  static Future<void> updateUser(Map<String, dynamic> user) async {
    final prefs = await _prefs;
    final current = await currentUser();
    final merged = <String, dynamic>{...?current, ...user};
    await _writeUser(prefs, merged);
    dataRevision.value++;
  }

  static Future<void> clear() async {
    try {
      await _secure.delete(key: tokenKey);
    } catch (_) {}
    final prefs = await _prefs;
    await prefs.remove(tokenKey);
    await prefs.remove(authModeKey);
    await prefs.remove(userIdKey);
    await prefs.remove(userKey);
    await prefs.remove(userNameKey);
    authRevision.value++;
    dataRevision.value++;
  }

  static Future<void> _writeUser(
    SharedPreferences prefs,
    Map<String, dynamic> user,
  ) async {
    await prefs.setString(userKey, jsonEncode(user));
    final id = (user['id'] as num?)?.toInt();
    if (id != null) {
      await prefs.setInt(userIdKey, id);
    }
    await prefs.setString(userNameKey, user['name']?.toString() ?? '');
  }
}
