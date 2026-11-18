import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session_service.dart';

/// Error dari API ArenaSports. Pesan sudah siap ditampilkan ke pengguna.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final dynamic errors;

  bool get isUnauthorized => statusCode == 401;

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

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _send('GET', path, query: query, auth: auth);
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

    final token = auth ? await SessionService.token() : null;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
    }

    _appendFields(request.fields, fields);
    request.files.addAll(files);

    try {
      final streamed = await request.send().timeout(ApiConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response, auth: auth);
    } on TimeoutException {
      throw const ApiException('Koneksi ke server timeout. Coba lagi.');
    } on http.ClientException {
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

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Accept'] = 'application/json';

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final token = auth ? await SessionService.token() : null;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    try {
      final streamed = await _http
          .send(request)
          .timeout(ApiConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response, auth: auth);
    } on TimeoutException {
      throw const ApiException('Koneksi ke server timeout. Coba lagi.');
    } on http.ClientException {
      throw _connectionError();
    } catch (e) {
      if (_isConnectionError(e)) throw _connectionError();
      rethrow;
    }
  }

  Uri _uri(String path, Map<String, String>? query) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}$normalized');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  dynamic _decode(http.Response response, {required bool auth}) {
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

      final message = _errorMessage(decoded);
      throw ApiException(
        message,
        statusCode: response.statusCode,
        errors: decoded['errors'],
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      decoded is Map && decoded['message'] != null
          ? _sanitizeError(decoded['message'].toString())
          : 'Permintaan gagal (HTTP ${response.statusCode}).',
      statusCode: response.statusCode,
    );
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
