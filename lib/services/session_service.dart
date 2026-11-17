import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sumber tunggal data sesi pengguna.
///
/// Token disimpan apa adanya agar dapat dipakai sebagai Bearer token, sedangkan
/// data pengguna disimpan sebagai JSON untuk kebutuhan tampilan cepat.
class SessionService {
  static const String tokenKey = 'token';
  static const String userKey = 'user';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';
  static const String authModeKey = 'auth_mode';

  /// Dipakai layar lain untuk memuat ulang data setelah profil/poin berubah.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<String?> token() async {
    final prefs = await _prefs;
    final value = prefs.getString(tokenKey);
    return value == null || value.isEmpty ? null : value;
  }

  static Future<bool> isLoggedIn() async => (await token()) != null;

  static Future<Map<String, dynamic>?> currentUser() async {
    final prefs = await _prefs;
    final raw = prefs.getString(userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
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
    final prefs = await _prefs;
    await prefs.setString(tokenKey, token);
    await prefs.setString(authModeKey, 'api');
    await _writeUser(prefs, user);
    revision.value++;
  }

  static Future<void> updateUser(Map<String, dynamic> user) async {
    final prefs = await _prefs;
    final current = await currentUser();
    final merged = <String, dynamic>{...?current, ...user};
    await _writeUser(prefs, merged);
    revision.value++;
  }

  static Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(tokenKey);
    await prefs.remove(authModeKey);
    await prefs.remove(userIdKey);
    await prefs.remove(userKey);
    await prefs.remove(userNameKey);
    revision.value++;
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
