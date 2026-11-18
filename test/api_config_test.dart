import 'package:flutter_test/flutter_test.dart';
import 'package:penyewaan_lapangan/config/api_config.dart';

void main() {
  test('media lokal diarahkan ke server aktif', () {
    final resolved = ApiConfig.resolveMediaUrl(
      'http://127.0.0.1:8000/storage/venues/foto.jpg',
    );

    expect(resolved, isNotNull);
    expect(resolved, startsWith('${ApiConfig.serverBaseUrl}/storage/venues/'));
    expect(resolved, isNot(contains('127.0.0.1')));
  });

  test('path media relatif memakai server aktif', () {
    expect(
      ApiConfig.resolveMediaUrl('storage/profiles/foto.jpg'),
      '${ApiConfig.serverBaseUrl}/storage/profiles/foto.jpg',
    );
  });

  test('URL server yang masih http dinaikkan ke skema server', () {
    final server = Uri.parse(ApiConfig.serverBaseUrl);
    final resolved = ApiConfig.resolveMediaUrl(
      'http://${server.host}/storage/profiles/foto.jpg',
    );

    expect(
      resolved,
      '${server.scheme}://${server.host}/storage/profiles/foto.jpg',
    );
  });
}
