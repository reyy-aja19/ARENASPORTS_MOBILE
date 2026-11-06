import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:penyewaan_lapangan/services/local_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('registered account can log in again from local storage', () async {
    final registeredUser = await LocalAuthService.register(
      name: 'Test User',
      email: 'user@example.com',
      phone: '08123456789',
      password: 'Password123',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('auth_mode');

    final loggedInUser = await LocalAuthService.login(
      identifier: 'user@example.com',
      password: 'Password123',
    );

    expect(registeredUser['id'], loggedInUser['id']);
    expect(loggedInUser['name'], 'Test User');
    expect(prefs.getString('auth_mode'), 'local');
    expect(prefs.getString('token'), isNotEmpty);

    final storedUsers = jsonDecode(prefs.getString('local_users')!) as List;
    expect(storedUsers.single['password_hash'], isNot('Password123'));
  });

  test('registration rejects duplicate email or phone', () async {
    await LocalAuthService.register(
      name: 'Test User',
      email: 'user@example.com',
      phone: '08123456789',
      password: 'Password123',
    );

    await expectLater(
      LocalAuthService.register(
        name: 'Another User',
        email: 'USER@example.com',
        phone: '08987654321',
        password: 'Password456',
      ),
      throwsA(isA<LocalAuthException>()),
    );
  });

  test('login rejects an incorrect password', () async {
    await LocalAuthService.register(
      name: 'Test User',
      email: 'user@example.com',
      phone: '08123456789',
      password: 'Password123',
    );

    await expectLater(
      LocalAuthService.login(
        identifier: 'user@example.com',
        password: 'Incorrect123',
      ),
      throwsA(isA<LocalAuthException>()),
    );
  });
}