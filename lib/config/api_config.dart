import 'package:flutter/foundation.dart';

class ApiConfig {
  static const Duration requestTimeout = Duration(seconds: 10);

  static const String _serverBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get serverBaseUrl {
    final override = _serverBaseUrlOverride.trim();
    if (override.isNotEmpty) {
      return override.replaceFirst(RegExp(r'/+$'), '');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static String get apiBaseUrl => '$serverBaseUrl/api';
}