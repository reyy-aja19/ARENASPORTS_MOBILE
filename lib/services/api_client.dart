import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_service.dart';

/// Error dari API ArenaSports. Pesan sudah siap ditampilkan ke pengguna.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.errors,
    this.retryAfterSeconds,
  });

  final String message;
  final int? statusCode;
  final dynamic errors;
  final int? retryAfterSeconds;

  bool get isUnauthorized => statusCode == 401;
  bool get isTooManyRequests => statusCode == 429;

  @override
  String toString() => message;
}

/// Klien HTTP tunggal untuk seluruh aplikasi.
///
/// Semua respons backend memakai envelope:
/// `{success, message, data, errors}`. Kelas ini mengembalikan `data` saja dan
/// melempar [ApiException] bila permintaan gagal.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static ApiException _connectionError() {
    return ApiException(
      'Tidak dapat terhubung ke server (${ApiConfig.serverBaseUrl}). '
      'Periksa koneksi internet perangkat lalu coba lagi.',
    );
  }

  final http.Client _http = http.Client();
  final Map<String, Future<dynamic>> _inflightGets = <String, Future<dynamic>>{};
  DateTime? _rateLimitUntil;

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    final key = _requestKey('GET', path, query: query, auth: auth);
    final existing = _inflightGets[key];
    if (existing != null) return existing;

    final future = _send('GET', path, query: query, auth: auth);
    _inflightGets[key] = future;
    return future.whenComplete(() {
      if (identical(_inflightGets[key], future)) {
        _inflightGets.remove(key);
      }
    });
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _send('POST', path, body: body, query: query, auth: auth);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _send('PUT', path, body: body, query: query, auth: auth);
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _send('DELETE', path, body: body, query: query, auth: auth);
  }

  /// Mengirim multipart. Nilai `fields` yang berupa list akan diubah menjadi
  /// `field[]` agar sesuai validasi Laravel.
  Future<dynamic> multipart(
    String path, {
    required Map<String, dynamic> fields,
    List<http.MultipartFile> files = const [],
    String method = 'POST',
    bool auth = true,
  }) async {
    final request = http.MultipartRequest(method, _uri(path, null));
    await _applyAuth(request.headers, auth: auth);

    _appendFields(request.fields, fields);
    request.files.addAll(files);

    try {
      final streamed = await request.send().timeout(ApiConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);
      _logRequest(method, path, response.statusCode);
      return _decode(response, auth: auth);
    } on TimeoutException {
      _logRequest(method, path, -1);
      throw const ApiException('Koneksi ke server timeout. Coba lagi.');
    } on http.ClientException {
      _logRequest(method, path, -1);
      throw _connectionError();
    } catch (e) {
      if (_isConnectionError(e)) throw _connectionError();
      rethrow;
    }
  }

  /// Membuat file multipart dari path (native). Tidak didukung di web.
  Future<http.MultipartFile> fileFromPath(
    String field,
    String path, {
    String? filename,
  }) {
    if (kIsWeb) {
      throw const ApiException(
        'Upload file dari path tidak didukung di web. Gunakan bytes.',
      );
    }
    return http.MultipartFile.fromPath(field, path, filename: filename);
  }

  /// Membuat file multipart dari bytes (aman untuk web dan native).
  http.MultipartFile fileFromBytes(
    String field,
    List<int> bytes, {
    String? filename,
  }) {
    return http.MultipartFile.fromBytes(field, bytes, filename: filename);
  }

  bool _isConnectionError(Object e) {
    final type = e.runtimeType.toString();
    return type == 'SocketException' ||
        type == 'XMLHttpRequest' ||
        type == 'ClientException';
  }

  /// Debug: log setiap request dari mobile — lihat apakah terjadi loop saat login.
  void _logRequest(String method, String path, int statusCode) {
    final trace = StackTrace.current
        .toString()
        .split('\n')
        .where((line) => line.contains('.dart'))
        .where(
          (line) => !line.contains('api_client') && !line.contains('api_service.dart'),
        )
        .take(8)
        .map((line) {
          final m = RegExp(r'([^\s/\\]+\.dart):(\d+)').firstMatch(line);
          return m != null ? '${m.group(1)}:${m.group(2)}' : '';
        })
        .where((s) => s.isNotEmpty)
        .join(' <- ');
    print(
      '[ApiClient] ${DateTime.now().millisecondsSinceEpoch}ms $method $path -> $statusCode | $trace',
    );
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    _throwIfRateLimited();

    final request = http.Request(method, _uri(path, query));
    request.headers['Accept'] = 'application/json';

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    await _applyAuth(request.headers, auth: auth);

    try {
      final streamed = await _http
          .send(request)
          .timeout(ApiConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);
      _logRequest(method, path, response.statusCode);
      return _decode(response, auth: auth);
    } on TimeoutException {
      _logRequest(method, path, -1);
      throw const ApiException('Koneksi ke server timeout. Coba lagi.');
    } on http.ClientException {
      _logRequest(method, path, -1);
      throw _connectionError();
    } catch (e) {
      if (_isConnectionError(e)) throw _connectionError();
      rethrow;
    }
  }

  Future<void> _applyAuth(
    Map<String, String> headers, {
    required bool auth,
  }) async {
    if (!auth) return;
    final token = await SessionService.token();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
  }

  void _throwIfRateLimited() {
    final until = _rateLimitUntil;
    if (until == null) return;
    final remaining = until.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _rateLimitUntil = null;
      return;
    }
    throw ApiException(
      'Terlalu banyak permintaan. Coba lagi dalam $remaining detik.',
      statusCode: 429,
      retryAfterSeconds: remaining,
    );
  }

  void _recordRateLimit(http.Response response) {
    final retryAfter = _parseRetryAfter(response.headers['retry-after']);
    final seconds = (retryAfter ?? 15).clamp(3, 120);
    final until = DateTime.now().add(Duration(seconds: seconds));
    final current = _rateLimitUntil;
    if (current == null || until.isAfter(current)) {
      _rateLimitUntil = until;
    }
  }

  int? _parseRetryAfter(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    final seconds = int.tryParse(raw);
    if (seconds != null) return seconds;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    final diff = date.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : null;
  }

  String _requestKey(
    String method,
    String path, {
    Map<String, String>? query,
    required bool auth,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final entries =
        query?.entries.toList() ?? <MapEntry<String, String>>[];
    entries.sort((a, b) => a.key.compareTo(b.key));
    final q = entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$method|$normalizedPath|$q|$auth';
  }

  Uri _uri(String path, Map<String, String>? query) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}$normalized');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  dynamic _decode(http.Response response, {required bool auth}) {
    if (response.statusCode == 429) {
      _recordRateLimit(response);
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode == 401 && auth) {
      unawaited(SessionService.clear());
    }

    if (decoded is Map<String, dynamic>) {
      final success = decoded['success'];
      if (success == true) return decoded['data'];

      final message = response.statusCode == 429
          ? _tooManyRequestsMessage(response)
          : _errorMessage(decoded);
      throw ApiException(
        message,
        statusCode: response.statusCode,
        errors: decoded['errors'],
        retryAfterSeconds: response.statusCode == 429
            ? _parseRetryAfter(response.headers['retry-after'])
            : null,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final rawMessage = decoded is Map && decoded['message'] != null
        ? _sanitizeError(decoded['message'].toString())
        : 'Permintaan gagal (HTTP ${response.statusCode}).';

    throw ApiException(
      response.statusCode == 429 ? _tooManyRequestsMessage(response) : rawMessage,
      statusCode: response.statusCode,
      retryAfterSeconds: response.statusCode == 429
          ? _parseRetryAfter(response.headers['retry-after'])
          : null,
    );
  }

  String _tooManyRequestsMessage(http.Response response) {
    final seconds = _parseRetryAfter(response.headers['retry-after']);
    if (seconds != null && seconds > 0) {
      return 'Terlalu banyak permintaan. Coba lagi dalam $seconds detik.';
    }
    return 'Terlalu banyak permintaan. Mohon tunggu sebentar lalu coba lagi.';
  }

  /// Pesan debug Laravel (SQL/host/path server) tidak boleh ditampilkan apa
  /// adanya di aplikasi. Pengguna cukup diberi tahu bahwa server bermasalah.
  String _sanitizeError(String message) {
    final text = message.trim();
    const internalMarkers = [
      'SQLSTATE',
      'Connection:',
      'vendor/laravel',
      '/var/www',
      'Stack trace',
      'Call to ',
      'Undefined ',
    ];

    if (internalMarkers.any(text.contains)) {
      return 'Server sedang bermasalah. Coba lagi beberapa saat lagi.';
    }

    return text;
  }

  String _errorMessage(Map<String, dynamic> decoded) {
    final errors = decoded['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return _sanitizeError(value.first.toString());
        }
        if (value != null && value.toString().isNotEmpty) {
          return _sanitizeError(value.toString());
        }
      }
    }

    final message = decoded['message']?.toString().trim();
    return message == null || message.isEmpty
        ? 'Permintaan gagal diproses server.'
        : _sanitizeError(message);
  }

  void _appendFields(Map<String, String> target, Map<String, dynamic> fields) {
    fields.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        var index = 0;
        for (final item in value) {
          if (item == null) continue;
          target['$key[$index]'] = item.toString();
          index++;
        }
        return;
      }
      if (value is bool) {
        target[key] = value ? '1' : '0';
      } else {
        target[key] = value.toString();
      }
    });
  }
}
