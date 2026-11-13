import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_model.dart';
import '../models/notification_model.dart';
import '../models/field_model.dart';
import 'local_auth_service.dart';

class LocalAppDataService {
  static final List<FieldModel> fields = [
    FieldModel(
      id: 1,
      name: 'Kelapa Gading Sports Indramayu',
      type: 'Futsal',
      courtCount: 1,
      price: 150000,
      imageUrl:
          'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=1200&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
      ],
      courts: _buildCourtInventory(
        count: 1,
        price: 150000,
        images: [
          'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=1200&q=80',
        ],
        facilities: [
          ['Rumput sintetis', 'Lampu lapangan', 'Ruang ganti'],
        ],
        descriptions: [
          'Lapangan futsal Kelapa Gading dengan area bermain khusus dan jadwal booking tersendiri.',
        ],
      ),
      description:
          'Satu lapangan futsal dengan rumput sintetis dan pencahayaan maksimal.',
      status: 'available',
      fasilitas: ['Parkir', 'Kamar mandi', 'Ruang ganti', 'Wi‑Fi'],
      latitude: -6.3265,
      longitude: 108.3250,
    ),
    FieldModel(
      id: 2,
      name: 'Kelapa Gading Sports Indramayu',
      type: 'Badminton',
      courtCount: 6,
      price: 50000,
      imageUrl:
          'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=1200&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1708312604109-16c0be9326cd?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=NHwxMjA3fDA%3D',
        'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=1200&q=80',
      ],
      courts: _buildCourtInventory(
        count: 6,
        price: 50000,
        images: [
          'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1708312604109-16c0be9326cd?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=NHwxMjA3fDA%3D',
        ],
        facilities: [
          ['Lantai vinyl', 'Lampu indoor', 'Area pemanasan'],
          ['Lantai vinyl', 'Lampu indoor', 'Area duduk pemain'],
          ['Lantai vinyl', 'Lampu indoor', 'Dekat kantin'],
          ['Lantai vinyl', 'Lampu indoor', 'Area pemanasan'],
          ['Lantai vinyl', 'Lampu indoor', 'Area duduk pemain'],
          ['Lantai vinyl', 'Lampu indoor', 'Dekat kantin'],
        ],
        descriptions: [
          'Lapangan badminton 1 indoor untuk permainan santai dan kompetitif.',
          'Lapangan badminton 2 indoor dengan area duduk pemain di sisi court.',
          'Lapangan badminton 3 indoor, berlokasi dekat area kantin.',
          'Lapangan badminton 4 indoor untuk permainan ganda dan latihan rutin.',
          'Lapangan badminton 5 indoor dengan ruang tunggu di sisi permainan.',
          'Lapangan badminton 6 indoor, cocok untuk latihan dan pertandingan.',
        ],
      ),
      description:
          'Enam lapangan badminton indoor dengan lantai anti selip dan area pemanasan.',
      status: 'available',
      fasilitas: ['Parkir', 'Kamar mandi', 'Kantin', 'Air minum'],
      latitude: -6.3265,
      longitude: 108.3250,
    ),
    FieldModel(
      id: 3,
      name: 'Futsal NCI',
      type: 'Futsal',
      courtCount: 6,
      price: 175000,
      imageUrl:
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
      ],
      courts: _buildCourtInventory(
        count: 6,
        price: 175000,
        images: [
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
          'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=1200&q=80',
        ],
        facilities: [
          ['Rumput sintetis', 'Lampu lapangan', 'Papan skor'],
          ['Rumput sintetis', 'Lampu lapangan', 'Area tunggu'],
          ['Rumput sintetis', 'Lampu lapangan', 'Jaring pembatas'],
          ['Rumput sintetis', 'Lampu lapangan', 'Papan skor'],
          ['Rumput sintetis', 'Lampu lapangan', 'Area tunggu'],
          ['Rumput sintetis', 'Lampu lapangan', 'Jaring pembatas'],
        ],
        descriptions: [
          'Lapangan futsal NCI 1 untuk pertandingan dan latihan tim.',
          'Lapangan futsal NCI 2 dengan area tunggu di sisi lapangan.',
          'Lapangan futsal NCI 3 dengan jaring pembatas di area permainan.',
          'Lapangan futsal NCI 4 untuk permainan tim dan latihan rutin.',
          'Lapangan futsal NCI 5 dengan ruang tunggu di sekitar court.',
          'Lapangan futsal NCI 6 untuk pertandingan dan sesi latihan.',
        ],
      ),
      description: 'Enam lapangan futsal untuk latihan tim dan pertandingan.',
      status: 'available',
      fasilitas: ['Parkir', 'Kamar mandi', 'Mushola', 'Cafe'],
      latitude: -6.3300,
      longitude: 108.3200,
    ),
  ];

  static List<CourtModel> _buildCourtInventory({
    required int count,
    required int price,
    required List<String> images,
    required List<List<String>> facilities,
    required List<String> descriptions,
  }) {
    return List.generate(
      count,
      (index) => CourtModel(
        number: index + 1,
        imageUrl: images[index % images.length],
        price: price,
        facilities: facilities[index],
        description: descriptions[index],
      ),
    );
  }

  static const List<Map<String, dynamic>> rewards = [
    {'id': 1, 'name': 'Voucher Booking Rp25.000', 'points': 100},
    {'id': 2, 'name': 'Diskon Booking 10%', 'points': 50},
    {'id': 3, 'name': 'Minuman Gratis', 'points': 25},
  ];

  static List<NotificationModel> get notifications => [
    NotificationModel(
      title: 'Selamat datang di Sporty',
      message: 'Cari lapangan dan ajak teman bermain hari ini.',
      type: 'info',
    ),
    NotificationModel(
      title: 'Poin bisa ditukar',
      message: 'Kumpulkan poin dari booking dan tukarkan dengan reward.',
      type: 'reward',
    ),
  ];

  static String _notificationsKey(int userId) => 'local_notifications_$userId';

  static Future<int?> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  static Future<List<NotificationModel>> getNotifications(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _notificationsKey(userId);
    if (!prefs.containsKey(key)) {
      final seeded = List<NotificationModel>.from(notifications);
      await prefs.setString(
        key,
        jsonEncode(seeded.map((n) => n.toJson()).toList()),
      );
      return seeded;
    }
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => NotificationModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<void> addNotification(
    int userId,
    NotificationModel notification,
  ) async {
    final list = await getNotifications(userId);
    list.insert(0, notification);
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationsKey(userId),
      jsonEncode(list.map((n) => n.toJson()).toList()),
    );
  }

  static Future<void> markAllNotificationsRead(int userId) async {
    final list = await getNotifications(userId);
    final updated = list
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationsKey(userId),
      jsonEncode(updated.map((n) => n.toJson()).toList()),
    );
  }

  static Future<void> deleteNotification(int userId, String id) async {
    final list = await getNotifications(userId);
    list.removeWhere((n) => n.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationsKey(userId),
      jsonEncode(list.map((n) => n.toJson()).toList()),
    );
  }

  static Future<void> clearNotifications(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey(userId));
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _bookingKey(int userId) => 'local_bookings_$userId';

  static const Set<String> _activeStatuses = {
    'pending',
    'dp',
    'lunas',
    'check in',
  };

  /// Mengembalikan status efektif sebuah booking.
  ///
  /// Booking yang masih aktif otomatis dianggap selesai ketika tanggal + jam
  /// selesainya sudah terlewati.
  static String effectiveStatus(Map<String, dynamic> booking, {DateTime? now}) {
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    if (!_activeStatuses.contains(status)) return status;

    final endAt = _bookingEndDateTime(booking);
    if (endAt == null) return status;

    return (now ?? DateTime.now()).isAfter(endAt) ? 'selesai' : status;
  }

  static DateTime? _bookingEndDateTime(Map<String, dynamic> booking) {
    final rawDate = booking['booking_date']?.toString();
    final rawEnd = booking['end_time']?.toString();
    if (rawDate == null || rawEnd == null) return null;

    final dateParts = rawDate.split('-');
    if (dateParts.length != 3) return null;

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);

    final timeParts = rawEnd.split(':');
    final hour = int.tryParse(timeParts.first);
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    return DateTime(year, month, day, hour, minute);
  }

  /// Menyimpan perubahan status otomatis. Return `true` jika ada yang berubah.
  static bool _applyAutoCompletion(List<Map<String, dynamic>> bookings) {
    var changed = false;
    final now = DateTime.now();
    for (final booking in bookings) {
      final status = (booking['status'] ?? '').toString().toLowerCase();
      final effective = effectiveStatus(booking, now: now);
      if (effective != status) {
        booking['status'] = effective;
        changed = true;
      }
    }
    return changed;
  }

  static Future<List<Map<String, dynamic>>> getBookingHistory(
    int userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _bookingKey(userId);
    final rawBookings = prefs.getString(key);
    if (rawBookings != null) {
      final bookings = _decodeList(rawBookings);
      final cleaned = _removeLegacyDemoBookings(bookings);
      if (cleaned.length != bookings.length) {
        await prefs.setString(key, jsonEncode(cleaned));
        return cleaned;
      }
      if (_applyAutoCompletion(cleaned)) {
        await prefs.setString(key, jsonEncode(cleaned));
      }
      return cleaned;
    }

    await prefs.setString(key, jsonEncode(<Map<String, dynamic>>[]));
    return [];
  }

  /// Menghapus data contoh lama yang pernah dibuat otomatis oleh aplikasi.
  /// Hanya data bawaan dengan nama default yang dihapus, bukan booking
  /// yang dibuat pengguna dari detail lapangan.
  static List<Map<String, dynamic>> _removeLegacyDemoBookings(
    List<Map<String, dynamic>> bookings,
  ) {
    return bookings.where((booking) {
      final lapangan = booking['lapangan'];
      final fieldName = lapangan is Map ? lapangan['nama']?.toString() : null;
      final paymentMethod = booking['payment_method']?.toString();
      final isLegacySample =
          fieldName == 'Lapangan Futsal Indramayu' &&
          paymentMethod == 'Simulasi lokal' &&
          booking['lapangan_id'] == 1 &&
          booking['total_price'] == 150000;
      return !isLegacySample;
    }).toList();
  }

  static Map<String, dynamic> _booking({
    required int id,
    required int userId,
    required String date,
    required String startTime,
    required String endTime,
    required num totalPrice,
    required String status,
    int fieldId = 1,
    String fieldName = 'Lapangan Futsal Indramayu',
    String paymentMethod = 'Simulasi lokal',
  }) {
    return {
      'id': id,
      'user_id': userId,
      'lapangan_id': fieldId,
      'lapangan': {
        'id': fieldId,
        'nama': fieldName,
        'nama_lapangan': fieldName,
      },
      'booking_date': date,
      'start_time': startTime,
      'end_time': endTime,
      'total_price': totalPrice,
      'status': status,
      'payment_method': paymentMethod,
      'is_demo': true,
    };
  }

  static List<Map<String, dynamic>> _decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<String>> getBookedSlots({
    required int fieldId,
    required String date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getInt('user_id');
    if (currentUserId != null) await getBookingHistory(currentUserId);

    final bookedSlots = <String>{};
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith('local_bookings_'),
    )) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final bookings = _removeLegacyDemoBookings(_decodeList(raw));
      if (jsonEncode(bookings) != raw) {
        await prefs.setString(key, jsonEncode(bookings));
      }
      for (final booking in bookings) {
        if (booking['lapangan_id'] != fieldId ||
            booking['booking_date'] != date ||
            ![
              'pending',
              'dp',
              'lunas',
              'check in',
            ].contains(booking['status']?.toString().toLowerCase())) {
          continue;
        }

        final startHour = int.tryParse(
          booking['start_time'].toString().split(':').first,
        );
        final endHour = int.tryParse(
          booking['end_time'].toString().split(':').first,
        );
        if (startHour == null || endHour == null) continue;
        for (var hour = startHour; hour < endHour; hour++) {
          bookedSlots.add('${hour.toString().padLeft(2, '0')}:00');
        }
      }
    }
    return bookedSlots.toList()..sort();
  }

  static Future<Map<String, dynamic>> createBooking({
    required int userId,
    required int fieldId,
    required String date,
    required String startTime,
    required String endTime,
    required num totalPrice,
    required int hours,
    String paymentMethod = 'Simulasi lokal',
    String? fieldName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bookings = await getBookingHistory(userId);
    final startHour = int.tryParse(startTime.split(':').first) ?? 0;
    final endHour = int.tryParse(endTime.split(':').first) ?? startHour + hours;

    final hasConflict = bookings.any((booking) {
      if (booking['lapangan_id'] != fieldId ||
          booking['booking_date'] != date ||
          ![
            'pending',
            'dp',
            'lunas',
            'check in',
          ].contains(booking['status']?.toString().toLowerCase())) {
        return false;
      }
      final bookedStart =
          int.tryParse(booking['start_time'].toString().split(':').first) ?? -1;
      final bookedEnd =
          int.tryParse(booking['end_time'].toString().split(':').first) ?? -1;
      return startHour < bookedEnd && endHour > bookedStart;
    });
    if (hasConflict) {
      return {'status': false, 'message': 'Jadwal tersebut baru saja terisi.'};
    }

    final nextId =
        bookings.fold<int>(0, (maxId, booking) {
          final id = booking['id'];
          return id is int && id > maxId ? id : maxId;
        }) +
        1;
    final bookingFieldName =
        fieldName ??
        switch (fieldId) {
          2 => 'Kelapa Gading Sports Indramayu • Badminton 1',
          3 => 'Futsal NCI • Futsal 1',
          _ => 'Kelapa Gading Sports Indramayu • Futsal 1',
        };
    bookings.insert(
      0,
      _booking(
        id: nextId,
        userId: userId,
        fieldId: fieldId,
        fieldName: bookingFieldName,
        date: date,
        startTime: startTime,
        endTime: endTime,
        totalPrice: totalPrice,
        status: 'lunas',
        paymentMethod: paymentMethod,
      ),
    );
    await prefs.setString(_bookingKey(userId), jsonEncode(bookings));

    await _incrementFieldBookingCount(fieldId);

    await addNotification(
      userId,
      NotificationModel(
        title: 'Booking Berhasil',
        message:
            '$bookingFieldName pada $date pukul $startTime-$endTime. Selamat bermain!',
        type: 'booking',
      ),
    );

    final user = await LocalAuthService.currentUser();
    final currentPoints = (user?['points'] as num?)?.toInt() ?? 0;
    final earnedPoints = hours * 10;
    await LocalAuthService.updateCurrentUser({
      'points': currentPoints + earnedPoints,
    });

    return {
      'status': true,
      'local_demo': true,
      'message': 'Booking simulasi berhasil disimpan.',
      'booking_id': nextId,
      'current_points': currentPoints + earnedPoints,
    };
  }

  static Future<List<MatchModel>> getMatches() async {
    final prefs = await SharedPreferences.getInstance();
    var matches = prefs.getString('local_matches');
    if (matches == null) {
      final now = DateTime.now();
      final seeded = [
        MatchModel(
          id: 1,
          title: 'Turnamen Badminton Kelapa Gading Cup',
          jenis: 'Badminton',
          tanggal: _date(now.add(const Duration(days: 7))),
          startTime: '08:00',
          endTime: '17:00',
          jumlahPemain: 32,
          jumlahBergabung: 18,
          status: 'Open',
          deskripsi:
              'Turnamen resmi ArenaSports untuk komunitas badminton Indramayu.',
          eventType: 'tournament',
          organizer: 'ArenaSports Admin',
          registrationFee: 50000,
          prize: 'Piala juara + Rp 3.000.000',
        ),
        MatchModel(
          id: 2,
          title: 'Turnamen Futsal Antar Komunitas',
          jenis: 'Futsal',
          tanggal: _date(now.add(const Duration(days: 14))),
          startTime: '09:00',
          endTime: '16:00',
          jumlahPemain: 16,
          jumlahBergabung: 10,
          status: 'Open',
          deskripsi:
              'Ajang turnamen tim futsal komunal, terbuka untuk semua tingkat.',
          eventType: 'tournament',
          organizer: 'ArenaSports Admin',
          registrationFee: 0,
          prize: 'Piala juara + Rp 1.500.000',
        ),
      ];
      matches = jsonEncode(seeded.map((match) => match.toJson()).toList());
      await prefs.setString('local_matches', matches);
    }

    final decoded = _decodeList(matches).map(MatchModel.fromJson).toList();
    final now = DateTime.now();
    final removable = decoded.where((match) {
      final endAt = _matchDateTime(match.tanggal, match.endTime);
      final isFinished = endAt != null && !endAt.isAfter(now);
      final isLegacySample =
          match.eventType == 'open_match' &&
          const {
            'Futsal Santai Sore',
            'Badminton Weekend',
          }.contains(match.title);
      return isFinished || isLegacySample;
    }).toList();

    if (removable.isNotEmpty) {
      final remaining = decoded
          .where((match) => !removable.contains(match))
          .toList();
      await _removeMatchArtifacts(removable);
      await prefs.setString(
        'local_matches',
        jsonEncode(remaining.map((match) => match.toJson()).toList()),
      );
      matches = jsonEncode(remaining.map((match) => match.toJson()).toList());
    }

    final cleaned = _decodeList(matches).map(MatchModel.fromJson).toList();
    cleaned.sort((first, second) {
      final dateOrder = first.tanggal.compareTo(second.tanggal);
      if (dateOrder != 0) return dateOrder;
      return first.startTime.compareTo(second.startTime);
    });
    return cleaned;
  }

  static DateTime? _matchDateTime(String date, String time) {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final timeParts = time.split(':');
    final hour = int.tryParse(timeParts.first);
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) : 0;
    if (hour == null || minute == null) return null;

    return DateTime(year, month, day, hour, minute);
  }

  static Future<void> _removeMatchArtifacts(List<MatchModel> matches) async {
    if (matches.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = matches.map((match) => match.id.toString()).toSet();

    for (final key in prefs.getKeys()) {
      if (!key.startsWith('local_joined_matches_') &&
          !key.startsWith('local_created_matches_')) {
        continue;
      }
      final current = prefs.getStringList(key) ?? [];
      final updated = current.where((id) => !ids.contains(id)).toList();
      if (updated.length != current.length) {
        await prefs.setStringList(key, updated);
      }
    }

    for (final match in matches) {
      await prefs.remove('local_match_messages_${match.id}');
    }
  }

  static Future<int> createMatch(MatchModel match) async {
    final prefs = await SharedPreferences.getInstance();
    final matches = await getMatches();
    final nextId =
        matches.fold<int>(
          0,
          (maxId, item) => item.id > maxId ? item.id : maxId,
        ) +
        1;
    final newMatch = MatchModel(
      id: nextId,
      title: match.title,
      jenis: match.jenis,
      tanggal: match.tanggal,
      startTime: match.startTime,
      endTime: match.endTime,
      jumlahPemain: match.jumlahPemain,
      jumlahBergabung: match.jumlahBergabung,
      status: match.status,
      deskripsi: match.deskripsi,
    );
    matches.add(newMatch);
    await prefs.setString(
      'local_matches',
      jsonEncode(matches.map((item) => item.toJson()).toList()),
    );
    return nextId;
  }

  static String _createdMatchesKey(int userId) =>
      'local_created_matches_$userId';

  static String _createdMatchBookingsKey(int userId) =>
      'local_created_match_bookings_$userId';

  /// Menandai bahwa [userId] telah membuat match dengan id [matchId].
  /// Jika [bookingId] diberikan, booking tersebut juga ditandai sudah
  /// memiliki open match.
  static Future<void> markMatchCreatedByUser(
    int userId,
    int matchId, {
    int? bookingId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final created =
        (prefs.getStringList(_createdMatchesKey(userId)) ?? []).toSet()
          ..add('$matchId');
    await prefs.setStringList(_createdMatchesKey(userId), created.toList());

    if (bookingId != null && bookingId > 0) {
      final bookings =
          (prefs.getStringList(_createdMatchBookingsKey(userId)) ?? []).toSet()
            ..add('$bookingId');
      await prefs.setStringList(
        _createdMatchBookingsKey(userId),
        bookings.toList(),
      );
    }
  }

  static Future<Set<int>> getCreatedMatchIds({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? prefs.getInt('user_id') ?? 0;
    final ids = prefs.getStringList(_createdMatchesKey(uid)) ?? [];
    return ids.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<Set<int>> getBookingsWithMatch({int? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? prefs.getInt('user_id') ?? 0;
    final ids = prefs.getStringList(_createdMatchBookingsKey(uid)) ?? [];
    return ids.map(int.tryParse).whereType<int>().toSet();
  }

  // ----------------------- RATING LAPANGAN -----------------------

  static const String _ratingsKey = 'local_field_ratings';

  static Future<List<Map<String, dynamic>>> _readRatings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ratingsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static Future<void> _writeRatings(List<Map<String, dynamic>> ratings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ratingsKey, jsonEncode(ratings));
  }

  static Future<Map<String, dynamic>?> getUserRatingForBooking(
    int bookingId,
  ) async {
    final ratings = await _readRatings();
    for (final r in ratings) {
      if (r['bookingId'] == bookingId) return r;
    }
    return null;
  }

  static Future<bool> hasRatedBooking(int bookingId) async {
    return (await getUserRatingForBooking(bookingId)) != null;
  }

  static Future<bool> submitRating({
    required int userId,
    required int fieldId,
    required int bookingId,
    required int rating,
    String comment = '',
  }) async {
    if (rating < 1 || rating > 5) return false;
    final ratings = await _readRatings();
    if (ratings.any((r) => r['bookingId'] == bookingId)) return false;
    ratings.add({
      'id':
          ratings.fold<int>(
            0,
            (m, r) => (r['id'] as int? ?? 0) > m ? r['id'] as int : m,
          ) +
          1,
      'userId': userId,
      'fieldId': fieldId,
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writeRatings(ratings);
    return true;
  }

  static Future<List<Map<String, dynamic>>> getFieldRatings(int fieldId) async {
    final ratings = await _readRatings();
    return ratings.where((r) => r['fieldId'] == fieldId).toList()..sort(
      (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
        a['createdAt']?.toString() ?? '',
      ),
    );
  }

  static Future<double> getAverageRating(int fieldId) async {
    final ratings = await getFieldRatings(fieldId);
    if (ratings.isEmpty) return 0;
    final sum = ratings.fold<int>(0, (s, r) => s + (r['rating'] as int? ?? 0));
    return sum / ratings.length;
  }

  static Future<int> getRatingCount(int fieldId) async {
    return (await getFieldRatings(fieldId)).length;
  }

  static Future<List<Map<String, dynamic>>> getUserRatings(int userId) async {
    final ratings = await _readRatings();
    return ratings.where((r) => r['userId'] == userId).toList();
  }

  // ----------------------- LOKASI & FAVORIT -----------------------

  static const String _fieldBookingCountsKey = 'local_field_booking_counts';

  static Future<Map<int, int>> getFieldBookingCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_fieldBookingCountsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final result = <int, int>{};
    decoded.forEach((k, v) {
      final id = int.tryParse(k.toString());
      final count = (v as num?)?.toInt();
      if (id != null && count != null) result[id] = count;
    });
    return result;
  }

  static Future<void> _incrementFieldBookingCount(int fieldId) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = await getFieldBookingCounts();
    counts[fieldId] = (counts[fieldId] ?? 0) + 1;
    await prefs.setString(
      _fieldBookingCountsKey,
      jsonEncode(counts.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  static Future<List<FieldModel>> getFavoriteFields({int limit = 5}) async {
    final counts = await getFieldBookingCounts();
    if (counts.isEmpty) return [];
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <FieldModel>[];
    for (final entry in sorted.take(limit)) {
      final field = fields.where((f) => f.id == entry.key).firstOrNull;
      if (field != null) result.add(field);
    }
    return result;
  }

  // ----------------------- TEMAN & CHAT LANGSUNG -----------------------

  static String _friendsKey(int userId) => 'local_friends_$userId';

  static String _dmKey(int a, int b) {
    final x = a < b ? a : b;
    final y = a < b ? b : a;
    return 'local_dm_${x}_$y';
  }

  static Future<List<Map<String, dynamic>>> getFriends(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_friendsKey(userId)) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    final allUsers = await LocalAuthService.getAllUsers();
    return allUsers.where((u) => ids.contains(u['id'])).toList();
  }

  static Future<bool> addFriend(int userId, int friendId) async {
    if (userId == friendId) return false;
    final prefs = await SharedPreferences.getInstance();
    final allUsers = await LocalAuthService.getAllUsers();
    if (!allUsers.any((u) => u['id'] == friendId)) return false;

    final ids = (prefs.getStringList(_friendsKey(userId)) ?? []).toSet();
    if (ids.contains('$friendId')) return false;
    ids.add('$friendId');
    await prefs.setStringList(_friendsKey(userId), ids.toList());
    return true;
  }

  static Future<void> removeFriend(int userId, int friendId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_friendsKey(userId)) ?? []).toSet()
      ..remove('$friendId');
    await prefs.setStringList(_friendsKey(userId), ids.toList());
  }

  static Future<List<Map<String, dynamic>>> searchUsers(
    int currentUserId,
    String query,
  ) async {
    final allUsers = await LocalAuthService.getAllUsers();
    final q = query.trim().toLowerCase();
    return allUsers.where((u) {
      if (u['id'] == currentUserId) return false;
      if (q.isEmpty) return true;
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getDMMessages(
    int userId,
    int friendId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dmKey(userId, friendId));
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static Future<void> sendDM(
    int userId,
    int friendId,
    String text,
    String senderName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = await getDMMessages(userId, friendId);
    msgs.add({
      'senderId': userId,
      'senderName': senderName,
      'text': text.trim(),
      'time': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_dmKey(userId, friendId), jsonEncode(msgs));
  }

  // ----------------------- PERMINTAAN PERTEMANAN -----------------------

  static const String _friendRequestsKey = 'local_friend_requests';

  static Future<List<Map<String, dynamic>>> _readFriendRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_friendRequestsKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static Future<void> _writeFriendRequests(
    List<Map<String, dynamic>> reqs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_friendRequestsKey, jsonEncode(reqs));
  }

  static Future<String> sendFriendRequest(
    int fromId,
    String fromName,
    int toId,
    String toName,
  ) async {
    if (fromId == toId) return 'self';
    final friends = await getFriends(fromId);
    if (friends.any((f) => f['id'] == toId)) return 'friends';

    final reqs = await _readFriendRequests();
    if (reqs.any(
      (r) => r['from'] == fromId && r['to'] == toId && r['status'] == 'pending',
    )) {
      return 'pending';
    }

    final newId =
        reqs.fold<int>(
          0,
          (m, r) => (r['id'] as int? ?? 0) > m ? r['id'] as int : m,
        ) +
        1;
    reqs.add({
      'id': newId,
      'from': fromId,
      'fromName': fromName,
      'to': toId,
      'toName': toName,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _writeFriendRequests(reqs);

    await addNotification(
      toId,
      NotificationModel(
        title: 'Permintaan Pertemanan',
        message: '$fromName mengirim permintaan pertemanan.',
        type: 'friend',
      ),
    );

    return 'sent';
  }

  static Future<List<Map<String, dynamic>>> getIncomingFriendRequests(
    int userId,
  ) async {
    final reqs = await _readFriendRequests();
    return reqs
        .where((r) => r['to'] == userId && r['status'] == 'pending')
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getOutgoingFriendRequests(
    int userId,
  ) async {
    final reqs = await _readFriendRequests();
    return reqs
        .where((r) => r['from'] == userId && r['status'] == 'pending')
        .toList();
  }

  static Future<void> acceptFriendRequest(int requestId, int userId) async {
    final reqs = await _readFriendRequests();
    final idx = reqs.indexWhere((r) => r['id'] == requestId);
    if (idx < 0) return;
    if (reqs[idx]['to'] != userId) return;
    reqs[idx]['status'] = 'accepted';
    await _writeFriendRequests(reqs);

    final fromId = reqs[idx]['from'] as int;
    final currentUser = await LocalAuthService.currentUser();
    final toName = currentUser?['name']?.toString() ?? 'Pengguna';
    await addFriend(userId, fromId);
    await addFriend(fromId, userId);

    await addNotification(
      fromId,
      NotificationModel(
        title: 'Permintaan Diterima',
        message: '$toName menerima permintaan pertemanan Anda.',
        type: 'friend',
      ),
    );
  }

  static Future<void> rejectFriendRequest(int requestId, int userId) async {
    final reqs = await _readFriendRequests();
    final idx = reqs.indexWhere((r) => r['id'] == requestId);
    if (idx < 0) return;
    if (reqs[idx]['to'] != userId) return;
    reqs[idx]['status'] = 'rejected';
    await _writeFriendRequests(reqs);
  }

  static Future<String> friendRequestStatus(int fromId, int toId) async {
    if (fromId == toId) return 'self';
    final friends = await getFriends(fromId);
    if (friends.any((f) => f['id'] == toId)) return 'friends';
    final reqs = await _readFriendRequests();
    if (reqs.any(
      (r) => r['from'] == fromId && r['to'] == toId && r['status'] == 'pending',
    )) {
      return 'pending_out';
    }
    if (reqs.any(
      (r) => r['from'] == toId && r['to'] == fromId && r['status'] == 'pending',
    )) {
      return 'pending_in';
    }
    return 'none';
  }

  static Future<Set<int>> getJoinedMatchIds() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    final joined = prefs.getStringList('local_joined_matches_$userId') ?? [];
    return joined.map(int.tryParse).whereType<int>().toSet();
  }

  static Future<Map<String, dynamic>> joinMatch(int matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final joinedKey = 'local_joined_matches_${userId ?? 0}';
    final joinedIds = prefs.getStringList(joinedKey) ?? [];
    if (joinedIds.contains('$matchId')) {
      return {
        'success': false,
        'message': 'Kamu sudah bergabung di match ini.',
      };
    }

    final matches = await getMatches();
    final index = matches.indexWhere((match) => match.id == matchId);
    if (index < 0) {
      return {'success': false, 'message': 'Match tidak ditemukan.'};
    }

    final match = matches[index];
    final matchStart = _matchDateTime(match.tanggal, match.startTime);
    if (matchStart != null && !DateTime.now().isBefore(matchStart)) {
      return {
        'success': false,
        'message': match.isTournament
            ? 'Turnamen sudah dimulai. Pendaftaran telah ditutup.'
            : 'Match sudah dimulai. Pendaftaran telah ditutup.',
      };
    }
    if (match.jumlahBergabung >= match.jumlahPemain) {
      return {'success': false, 'message': 'Match sudah penuh.'};
    }

    matches[index] = MatchModel(
      id: match.id,
      title: match.title,
      jenis: match.jenis,
      tanggal: match.tanggal,
      startTime: match.startTime,
      endTime: match.endTime,
      jumlahPemain: match.jumlahPemain,
      jumlahBergabung: match.jumlahBergabung + 1,
      status: match.status,
      deskripsi: match.deskripsi,
    );
    joinedIds.add('$matchId');
    await prefs.setStringList(joinedKey, joinedIds);
    await prefs.setString(
      'local_matches',
      jsonEncode(matches.map((item) => item.toJson()).toList()),
    );
    return {'success': true, 'message': 'Berhasil bergabung ke match.'};
  }

  static Future<List<dynamic>> getMessages(int matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_match_messages_$matchId';
    final rawMessages = prefs.getString(key);
    if (rawMessages != null) return _decodeList(rawMessages);

    final messages = [
      {
        'user': {'name': 'Raka'},
        'message': 'Halo, teman-teman! Sampai ketemu di lapangan.',
      },
      {
        'user': {'name': 'Dimas'},
        'message': 'Siap. Jangan lupa bawa sepatu futsal ya.',
      },
    ];
    await prefs.setString(key, jsonEncode(messages));
    return messages;
  }

  static Future<bool> sendMessage(int matchId, String message) async {
    final prefs = await SharedPreferences.getInstance();
    final user = await LocalAuthService.currentUser();
    final key = 'local_match_messages_$matchId';
    final messages = await getMessages(matchId);
    messages.add({
      'user': {'name': user?['name'] ?? 'Saya'},
      'message': message,
    });
    await prefs.setString(key, jsonEncode(messages));
    return true;
  }

  static Map<String, dynamic> getRewards() => {
    'status': true,
    'data': rewards.map((reward) => Map<String, dynamic>.from(reward)).toList(),
  };

  static Future<Map<String, dynamic>> redeemReward(int rewardId) async {
    final reward = rewards.where((item) => item['id'] == rewardId).firstOrNull;
    final user = await LocalAuthService.currentUser();
    if (reward == null || user == null) {
      return {'status': false, 'message': 'Reward atau akun tidak ditemukan.'};
    }

    final currentPoints = (user['points'] as num?)?.toInt() ?? 0;
    final requiredPoints = (reward['points'] as num).toInt();
    if (currentPoints < requiredPoints) {
      return {
        'status': false,
        'message': 'Poin kamu belum cukup untuk reward ini.',
      };
    }

    final remainingPoints = currentPoints - requiredPoints;
    await LocalAuthService.updateCurrentUser({'points': remainingPoints});
    return {
      'status': true,
      'kode_redeem':
          'DEMO-${DateTime.now().microsecondsSinceEpoch.toString().substring(8)}',
      'current_points': remainingPoints,
    };
  }

  static Future<void> saveVenueRequest({
    required int userId,
    required String venueName,
    required String address,
    required String phone,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final requests = _decodeList(
      prefs.getString('local_venue_requests') ?? '[]',
    );
    requests.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch,
      'user_id': userId,
      'venue_name': venueName.trim(),
      'address': address.trim(),
      'phone': phone.trim(),
      'reason': reason.trim(),
      'status': 'Menunggu verifikasi',
      'submitted_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString('local_venue_requests', jsonEncode(requests));
  }
}
