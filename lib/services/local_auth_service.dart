import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthException implements Exception {
  final String message;

  const LocalAuthException(this.message);

  @override
  String toString() => message;
}

class LocalAuthService {
  static const String _usersKey = 'local_users';
  static const int _passwordIterations = 100000;

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final users = _readUsers(prefs);
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPhone = phone.trim();

    if (users.any(
      (user) =>
          user['email'] == normalizedEmail || user['phone'] == normalizedPhone,
    )) {
      throw const LocalAuthException('Email atau nomor HP sudah terdaftar.');
    }

    final salt = base64UrlEncode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    final passwordHash = await compute(_derivePasswordHash, [
      password,
      salt,
      _passwordIterations.toString(),
    ]);
    final id =
        users.fold<int>(0, (maxId, user) {
          final currentId = user['id'];
          return currentId is int && currentId > maxId ? currentId : maxId;
        }) +
        1;

    final storedUser = <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'email': normalizedEmail,
      'phone': normalizedPhone,
      'points': 0,
      'role': 'user',
      'status': 'Aktif',
      'password_salt': salt,
      'password_hash': passwordHash,
    };
    users.add(storedUser);
    await prefs.setString(_usersKey, jsonEncode(users));

    final user = _publicUser(storedUser);
    await _saveSession(prefs, user);
    return user;
  }

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final users = _readUsers(prefs);
    final normalizedIdentifier = identifier.trim().toLowerCase();

    for (final user in users) {
      final email = user['email']?.toString().toLowerCase();
      final phone = user['phone']?.toString();
      if (email != normalizedIdentifier && phone != identifier.trim()) {
        continue;
      }

      final salt = user['password_salt']?.toString();
      final storedHash = user['password_hash']?.toString();
      if (salt == null || storedHash == null) break;

      final passwordHash = await compute(_derivePasswordHash, [
        password,
        salt,
        _passwordIterations.toString(),
      ]);
      if (passwordHash != storedHash) break;

      final publicUser = _publicUser(user);
      await _saveSession(prefs, publicUser);
      return publicUser;
    }

    throw const LocalAuthException('Email/nomor HP atau password salah.');
  }

  static Future<Map<String, dynamic>?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('user');
    if (rawUser == null) return null;
    return Map<String, dynamic>.from(jsonDecode(rawUser));
  }

  static Future<void> updateCurrentUser(Map<String, dynamic> updates) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = await LocalAuthService.currentUser();
    if (currentUser == null) return;

    currentUser.addAll(updates);
    await prefs.setString('user', jsonEncode(currentUser));

    final users = _readUsers(prefs);
    final userId = currentUser['id'];
    final userIndex = users.indexWhere((user) => user['id'] == userId);
    if (userIndex >= 0) {
      users[userIndex].addAll(updates);
      await prefs.setString(_usersKey, jsonEncode(users));
    }
  }

  static List<Map<String, dynamic>> _readUsers(SharedPreferences prefs) {
    final rawUsers = prefs.getString(_usersKey);
    if (rawUsers == null) return [];

    final decoded = jsonDecode(rawUsers);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((user) => Map<String, dynamic>.from(user))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    return _readUsers(prefs).map(_publicUser).toList();
  }

  static Map<String, dynamic> _publicUser(Map<String, dynamic> user) {
    return Map<String, dynamic>.from(user)
      ..remove('password_salt')
      ..remove('password_hash');
  }

  static Future<void> _saveSession(
    SharedPreferences prefs,
    Map<String, dynamic> user,
  ) async {
    await prefs.setString('auth_mode', 'local');
    await prefs.setString('token', 'local:${user['id']}');
    await prefs.setInt('user_id', user['id'] as int);
    await prefs.setString('user', jsonEncode(user));
    await prefs.setString('user_name', user['name']?.toString() ?? '');
  }
}

String _derivePasswordHash(List<String> input) {
  final password = utf8.encode(input[0]);
  final salt = base64Url.decode(input[1]);
  final iterations = int.parse(input[2]);
  final hmac = Hmac(sha256, password);
  var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final derivedKey = List<int>.from(block);

  for (var iteration = 1; iteration < iterations; iteration++) {
    block = hmac.convert(block).bytes;
    for (var index = 0; index < derivedKey.length; index++) {
      derivedKey[index] ^= block[index];
    }
  }

  return base64UrlEncode(derivedKey);
}
