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
      name: 'Lapangan Futsal Indramayu',
      type: 'Futsal',
      price: 150000,
      imageUrl:
          'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=1200&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
      ],
      description:
          'Lapangan futsal premium dengan rumput sintetis dan pencahayaan maksimal.',
      status: 'available',
      fasilitas: ['Parkir', 'Kamar mandi', 'Ruang ganti', 'Wi‑Fi'],
    ),
    FieldModel(
      id: 2,
      name: 'GOR Badminton Sport Center',
      type: 'Badminton',
      price: 50000,
      imageUrl:
          'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=1200&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1708312604109-16c0be9326cd?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=NHwxMjA3fDA%3D',
        'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=1200&q=80',
      ],
      description:
          'Lapangan badminton indoor dengan lantai anti selip dan area pemanasan.',
      status: 'available',
      fasilitas: ['Parkir', 'Kamar mandi', 'Kantin', 'Air minum'],
    ),
    FieldModel(
      id: 3,
      name: 'Arena Futsal Sport Center',
      type: 'Futsal',
      price: 175000,
      imageUrl:
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1543351611-58f69d7c1781?auto=format&fit=crop&w=1200&q=80',
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=1200&q=80',
      ],
      description:
          'Arena futsal modern untuk latihan tim, turnamen kecil, dan hangout santai.',
      status: 'available',
      fasilitas: ['Parkir', 'Kamar mandi', 'Mushola', 'Cafe'],
    ),
  ];

  static const List<Map<String, dynamic>> rewards = [
    {'id': 1, 'name': 'Voucher Booking Rp25.000', 'points': 100},
    {'id': 2, 'name': 'Diskon Booking 10%', 'points': 50},
    {'id': 3, 'name': 'Minuman Gratis', 'points': 25},
  ];

  static List<NotificationModel> get notifications => [
    NotificationModel(
      title: 'Selamat datang di Sporty',
      message: 'Cari lapangan dan ajak teman bermain hari ini.',
      time: 'Baru saja',
      type: 'info',
    ),
    NotificationModel(
      title: 'Poin bisa ditukar',
      message: 'Kumpulkan poin dari booking dan tukarkan dengan reward.',
      time: 'Hari ini',
      type: 'reward',
    ),
  ];

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _bookingKey(int userId) => 'local_bookings_$userId';

  static Future<List<Map<String, dynamic>>> getBookingHistory(
    int userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _bookingKey(userId);
    final rawBookings = prefs.getString(key);
    if (rawBookings != null) return _decodeList(rawBookings);

    final now = DateTime.now();
    final sampleBookings = [
      _booking(
        id: userId * 1000 + 1,
        userId: userId,
        date: _date(now.add(const Duration(days: 1))),
        startTime: '19:00',
        endTime: '20:00',
        totalPrice: 150000,
        status: 'lunas',
      ),
      _booking(
        id: userId * 1000 + 2,
        userId: userId,
        date: _date(now.subtract(const Duration(days: 3))),
        startTime: '17:00',
        endTime: '18:00',
        totalPrice: 150000,
        status: 'selesai',
      ),
    ];
    await prefs.setString(key, jsonEncode(sampleBookings));
    return sampleBookings;
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
      for (final booking in _decodeList(raw)) {
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
    final fieldName = switch (fieldId) {
      2 => 'GOR Badminton Sport Center',
      3 => 'Arena Futsal Sport Center',
      _ => 'Lapangan Futsal Indramayu',
    };
    bookings.insert(
      0,
      _booking(
        id: nextId,
        userId: userId,
        fieldId: fieldId,
        fieldName: fieldName,
        date: date,
        startTime: startTime,
        endTime: endTime,
        totalPrice: totalPrice,
        status: 'lunas',
        paymentMethod: paymentMethod,
      ),
    );
    await prefs.setString(_bookingKey(userId), jsonEncode(bookings));

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
          title: 'Futsal Santai Sore',
          jenis: 'Futsal',
          tanggal: _date(now.add(const Duration(days: 1))),
          startTime: '19:00',
          endTime: '20:00',
          jumlahPemain: 10,
          jumlahBergabung: 6,
          status: 'Open',
          deskripsi: 'Main santai, semua level boleh ikut.',
        ),
        MatchModel(
          id: 2,
          title: 'Badminton Weekend',
          jenis: 'Badminton',
          tanggal: _date(now.add(const Duration(days: 2))),
          startTime: '09:00',
          endTime: '11:00',
          jumlahPemain: 4,
          jumlahBergabung: 2,
          status: 'Open',
          deskripsi: 'Cari partner doubles untuk akhir pekan.',
        ),
      ];
      matches = jsonEncode(seeded.map((match) => match.toJson()).toList());
      await prefs.setString('local_matches', matches);
    }

    return _decodeList(matches).map(MatchModel.fromJson).toList()
      ..sort((first, second) => first.tanggal.compareTo(second.tanggal));
  }

  static Future<bool> createMatch(MatchModel match) async {
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
    return true;
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
    if (index < 0)
      return {'success': false, 'message': 'Match tidak ditemukan.'};

    final match = matches[index];
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
