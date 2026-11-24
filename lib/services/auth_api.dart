import 'api_client.dart';
import 'session_service.dart';

class AuthApi {
  static const String _deviceName = 'flutter-mobile';

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final data = await ApiClient.instance.post(
      '/auth/login',
      auth: false,
      body: {
        'identifier': identifier.trim(),
        'password': password,
        'device_name': _deviceName,
      },
    );
    return _applySession(data);
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? turnstileToken,
  }) async {
    final data = await ApiClient.instance.post(
      '/auth/register',
      auth: false,
      body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
        'password_confirmation': password,
        'device_name': _deviceName,
        if (turnstileToken != null && turnstileToken.isNotEmpty)
          'cf-turnstile-response': turnstileToken,
      },
    );
    return _applySession(data);
  }

  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final data = await ApiClient.instance.post(
      '/auth/google',
      auth: false,
      body: {'id_token': idToken, 'device_name': 'flutter-google'},
    );
    return _applySession(data);
  }

  static Future<Map<String, dynamic>> requestWhatsAppOtp({
    required String phone,
    String purpose = 'login',
    String? name,
    String? turnstileToken,
  }) async {
    final data = await ApiClient.instance.post(
      '/auth/whatsapp/request',
      auth: false,
      body: {
        'phone': phone.trim(),
        'purpose': purpose,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (turnstileToken != null && turnstileToken.isNotEmpty)
          'cf-turnstile-response': turnstileToken,
      },
    );
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static Future<Map<String, dynamic>> verifyWhatsAppOtp({
    required String otpToken,
    required String otp,
  }) async {
    final data = await ApiClient.instance.post(
      '/auth/whatsapp/verify',
      auth: false,
      body: {
        'otp_token': otpToken,
        'otp': otp.trim(),
        'device_name': 'flutter-whatsapp',
      },
    );
    return _applySession(data);
  }

  static Future<void> forgotPassword(String email) async {
    await ApiClient.instance.post(
      '/auth/forgot-password',
      auth: false,
      body: {'email': email.trim().toLowerCase()},
    );
  }

  /// Selesaikan alur reset password setelah menerima token via email.
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String email,
    required String password,
  }) async {
    final data = await ApiClient.instance.post(
      '/auth/reset-password',
      auth: false,
      body: {
        'token': token.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': password,
      },
    );
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// Hapus sesi lain milik akun ini (POST /auth/logout-all).
  static Future<void> logoutAll() async {
    try {
      await ApiClient.instance.post('/auth/logout-all');
    } catch (_) {
      // Sesi lokal tetap dibersihkan meskipun server tidak dapat dihubungi.
    } finally {
      await SessionService.clear();
    }
  }

  static Future<Map<String, dynamic>> me() async {
    final data = await ApiClient.instance.get('/auth/me');
    final user = _userFrom(data);
    if (user != null) await SessionService.updateUser(user);
    return user ?? const {};
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    await ApiClient.instance.post(
      '/auth/change-password',
      body: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  static Future<void> logout() async {
    try {
      await ApiClient.instance.post('/auth/logout');
    } catch (_) {
      // Sesi lokal tetap dibersihkan meskipun server tidak dapat dihubungi.
    } finally {
      await SessionService.clear();
    }
  }

  static Future<Map<String, dynamic>> _applySession(dynamic data) async {
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final token = map['token']?.toString();
    final user = _userFrom(map);

    if (token == null || token.isEmpty || user == null) {
      throw const ApiException('Respons login dari server tidak lengkap.');
    }

    await SessionService.save(token: token, user: user);
    return user;
  }

  static Map<String, dynamic>? _userFrom(dynamic data) {
    if (data is! Map) return null;
    final user = data['user'];
    return user is Map ? Map<String, dynamic>.from(user) : null;
  }
}
