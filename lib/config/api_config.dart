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

  /// Menormalkan URL media dari API agar tetap bisa dibuka di perangkat.
  ///
  /// Backend terkadang menghasilkan URL dengan host `localhost`/`127.0.0.1`
  /// (misalnya dari `APP_URL`). Di emulator/perangkat, host tersebut bukan
  /// komputer server, sehingga gambar gagal dimuat. URL media lokal diganti
  /// dengan host [serverBaseUrl] yang sedang dipakai aplikasi.
  static String? resolveMediaUrl(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri == null) return text;

    final server = Uri.tryParse(serverBaseUrl);
    if (server == null) return text;

    if (!uri.hasScheme) {
      final path = text.startsWith('/') ? text : '/$text';
      return '$serverBaseUrl$path';
    }

    const localHosts = {'127.0.0.1', 'localhost', '0.0.0.0'};
    if (!localHosts.contains(uri.host)) return text;

    final port = server.hasPort ? ':${server.port}' : '';
    final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '${server.scheme}://${server.host}$port$path$query';
  }
}