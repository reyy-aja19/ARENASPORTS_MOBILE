class ApiConfig {
  static const Duration requestTimeout = Duration(seconds: 60);

  /// Alamat root backend ARENASPORTS yang sudah di-deploy (Railway).
  ///
  /// Sama dengan domain yang dipakai versi web, sehingga aplikasi mobile
  /// langsung terhubung ke server produksi tanpa konfigurasi tambahan.
  static const String productionBaseUrl = 'https://arenasports.up.railway.app';

  /// Override opsional saat menjalankan aplikasi, misalnya untuk backend lokal:
  ///
  /// ```bash
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  /// ```
  static const String _serverBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get serverBaseUrl {
    final override = _serverBaseUrlOverride.trim();
    if (override.isNotEmpty) {
      return _normalizeOverride(override);
    }

    return productionBaseUrl;
  }

  static String get apiBaseUrl => '$serverBaseUrl/api';

  /// Menormalkan nilai `API_BASE_URL` agar tidak menghasilkan URL ganda
  /// seperti `/api/api` atau `http://host:8000/`.
  static String _normalizeOverride(String value) {
    var url = value.trim();

    // Tambahkan skema bila pengguna hanya menulis host:port.
    if (!url.contains('://')) {
      url = 'http://$url';
    }

    url = url.replaceFirst(RegExp(r'/+$'), '');

    // Aplikasi menambahkan `/api` sendiri, jadi buang bila sudah ditulis.
    if (url.toLowerCase().endsWith('/api')) {
      url = url.substring(0, url.length - '/api'.length);
    }

    return url.replaceFirst(RegExp(r'/+$'), '');
  }

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
    final sameHost = uri.host == server.host;
    final shouldRewrite =
        localHosts.contains(uri.host) ||
        (sameHost && uri.scheme != server.scheme);
    if (!shouldRewrite) return text;

    final port = server.hasPort ? ':${server.port}' : '';
    final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '${server.scheme}://${server.host}$port$path$query';
  }
}
