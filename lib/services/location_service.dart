import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Kesalahan lokasi dengan pesan yang siap ditampilkan ke pengguna.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Layanan lokasi bersama untuk fitur venue terdekat.
class LocationService {
  const LocationService._();

  /// Mendapatkan posisi pengguna sekaligus menangani izin dan layanan GPS.
  static Future<Position> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(
          'Aktifkan layanan lokasi perangkat untuk mencari venue terdekat.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.unableToDetermine) {
        // Sebagian perangkat belum bisa menentukan izin pada percobaan
        // pertama. Cek ulang sekali sebelum menyerah.
        permission = await Geolocator.checkPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        throw const LocationException(
          'Izin lokasi ditolak. Ketuk tombol lokasi untuk mencoba lagi.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(
          'Izin lokasi ditolak permanen. Aktifkan izin lokasi di Pengaturan.',
        );
      }

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } on TimeoutException {
        return await _lastKnownPosition();
      }
    } on TimeoutException {
      return await _lastKnownPosition();
    } on LocationServiceDisabledException {
      throw const LocationException(
        'Aktifkan layanan lokasi perangkat untuk mencari venue terdekat.',
      );
    } on PermissionDeniedException {
      throw const LocationException(
        'Izin lokasi diperlukan untuk mencari venue terdekat.',
      );
    } on MissingPluginException {
      throw const LocationException(
        'Fitur lokasi tidak tersedia pada perangkat ini.',
      );
    } on PlatformException {
      throw const LocationException(
        'Lokasi perangkat gagal didapatkan. Coba lagi.',
      );
    }
  }

  /// Mengambil posisi terakhir yang diketahui bila pembacaan GPS baru
  /// melebihi batas waktu.
  static Future<Position> _lastKnownPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    } catch (_) {
      // Abaikan dan tampilkan pesan timeout di bawah.
    }

    throw const LocationException(
      'Waktu mendapatkan lokasi habis. Coba lagi sebentar.',
    );
  }

  /// Mengubah koordinat menjadi nama daerah yang ramah dibaca.
  static Future<String?> describe(Position position) async {
    try {
      final placemarks = await Geocoding(
        locale: const Locale('id', 'ID'),
      ).placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 6));
      for (final placemark in placemarks) {
        final name = _formatPlacemark(placemark);
        if (name != null && name.isNotEmpty) return name;
      }
    } on TimeoutException {
      // Geocoding bawaan lambat, lanjut ke layanan daring.
    } on PlatformException {
      // Geocoding bawaan perangkat tidak tersedia, coba layanan daring.
    } on MissingPluginException {
      // Sama seperti di atas.
    }

    final nominatim = await _lookupLocationName(position);
    if (nominatim != null && nominatim.isNotEmpty) return nominatim;

    // Nominatim bisa diblokir CORS di platform web, jadi pakai layanan
    // gratis yang ramah browser sebagai cadangan terakhir.
    return _lookupBigDataCloud(position);
  }

  static String? _formatPlacemark(Placemark placemark) {
    final area =
        [
              placemark.subLocality,
              placemark.locality,
              placemark.subAdministrativeArea,
              placemark.administrativeArea,
            ]
            .map((value) => value?.trim())
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => null,
            );
    if (area == null || area.isEmpty) return null;

    final detail =
        [
              placemark.locality,
              placemark.subAdministrativeArea,
              placemark.administrativeArea,
            ]
            .map((value) => value?.trim())
            .firstWhere(
              (value) => value != null && value.isNotEmpty && value != area,
              orElse: () => null,
            );
    return detail == null ? area : '$area, $detail';
  }

  static Future<String?> _lookupLocationName(Position position) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': position.latitude.toString(),
      'lon': position.longitude.toString(),
      'zoom': '16',
      'addressdetails': '1',
    });

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Accept-Language': 'id',
              'User-Agent': 'ARENASPORTS/1.0',
            },
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic>) return null;
      final address = result['address'];
      if (address is! Map<String, dynamic>) return null;

      final area = _firstAddressValue(address, [
        'village',
        'hamlet',
        'suburb',
        'neighbourhood',
        'quarter',
        'residential',
        'subdistrict',
        'district',
        'city_district',
        'town',
        'municipality',
        'city',
        'county',
        'state_district',
      ]);
      if (area == null) return null;

      final region = _firstAddressValue(address, [
        'city',
        'town',
        'county',
        'state_district',
        'state',
      ]);
      return region == null || region == area ? area : '$area, $region';
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  /// Cadangan untuk platform web: Nominatim tidak mengirim header CORS,
  /// sedangkan BigDataCloud reverse-geocode-client mengizinkannya.
  static Future<String?> _lookupBigDataCloud(Position position) async {
    final uri = Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
      'localityLanguage': 'id',
    });

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic>) return null;

      String? clean(dynamic value) {
        final text = value?.toString().trim();
        return text == null || text.isEmpty ? null : text;
      }

      final city = clean(result['city']) ?? clean(result['locality']);
      final locality = clean(result['locality']);
      final province = clean(result['principalSubdivision']);

      if (locality != null && city != null && locality != city) {
        return '$locality, $city';
      }
      if (city != null && province != null && city != province) {
        return '$city, $province';
      }
      return city ?? province;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  static String? _firstAddressValue(
    Map<String, dynamic> address,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
