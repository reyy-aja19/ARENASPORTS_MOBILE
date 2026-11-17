import 'package:flutter/foundation.dart';

import '../models/booking_model.dart';
import '../models/match_model.dart';
import 'api_client.dart';
import 'api_service.dart';

/// Hasil satu kali muat data Open Match dari API.
class MatchFeed {
  const MatchFeed({
    required this.matches,
    required this.eligibleBookings,
  });

  /// Gabungan Open Match dan Turnamen yang dipublikasikan.
  final List<MatchModel> matches;

  /// Booking milik pengguna yang masih bisa dipakai membuat Open Match.
  final List<BookingModel> eligibleBookings;
}

class MatchApi {
  static Future<MatchFeed> fetchFeed() async {
    final data = await ApiClient.instance.get('/open-matches');
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    final matches = (map['matches'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MatchModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final events = (map['events'] as List? ?? [])
        .whereType<Map>()
        .map((item) => MatchModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final eligible = (map['eligible_bookings'] as List? ?? [])
        .whereType<Map>()
        .map((item) => BookingModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return MatchFeed(
      matches: [...matches, ...events],
      eligibleBookings: eligible,
    );
  }

  static Future<List<MatchModel>> fetchMatches() async {
    return (await fetchFeed()).matches;
  }

  static Future<List<BookingModel>> fetchEligibleBookings() async {
    return (await fetchFeed()).eligibleBookings;
  }

  static Future<Set<int>> fetchJoinedMatchIds() async {
    final matches = await fetchMatches();
    return matches.where((match) => match.joined).map((m) => m.id).toSet();
  }

  static Future<Set<int>> fetchCreatedMatchIds() async {
    final matches = await fetchMatches();
    return matches.where((match) => match.isHost).map((m) => m.id).toSet();
  }

  /// ID booking milik pengguna yang sudah memiliki Open Match aktif.
  static Future<Set<int>> fetchBookingsWithMatch() async {
    final bookings = await ApiService.instance.bookings();
    return bookings
        .where((booking) => booking.openMatchId != null)
        .map((booking) => booking.id)
        .toSet();
  }

  static Future<MatchModel> createMatch({
    required int bookingId,
    required String title,
    required int jumlahPemain,
    String deskripsi = '',
  }) async {
    final data = await ApiClient.instance.post(
      '/open-matches',
      body: {
        'booking_id': bookingId,
        'title': title,
        'jumlah_pemain': jumlahPemain,
        'deskripsi': deskripsi,
      },
    );
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    bumpData();
    return MatchModel.fromJson(
      map['match'] is Map
          ? Map<String, dynamic>.from(map['match'] as Map)
          : const {},
    );
  }

  /// Mengembalikan peta `{success, message, match}` agar layar bisa menampilkan
  /// pesan langsung dari server tanpa melempar error.
  static Future<Map<String, dynamic>> joinMatch(int matchId) async {
    try {
      final data = await ApiClient.instance.post('/open-matches/$matchId/join');
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      bumpData();
      return {
        'success': true,
        'message': 'Berhasil bergabung ke Open Match.',
        'match': map['match'],
      };
    } on ApiException catch (error) {
      return {'success': false, 'message': error.message};
    }
  }

  /// Pesan baru saja (opsional) agar polling hanya mengambil yang belum ada.
  static Future<List<Map<String, dynamic>>> fetchMessages(
    int matchId, {
    int after = 0,
  }) async {
    final data = await ApiClient.instance.get(
      '/open-matches/$matchId/messages',
      query: after > 0 ? {'after': '$after'} : null,
    );
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return (map['messages'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<int> lastMessageId(int matchId) async {
    final data = await ApiClient.instance.get(
      '/open-matches/$matchId/messages',
    );
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final last = map['last_id'];
    return last is num ? last.toInt() : int.tryParse('$last') ?? 0;
  }

  /// Kirim teks dan/atau satu lampiran gambar.
  static Future<bool> sendMessage(
    int matchId,
    String message, {
    String? attachmentPath,
  }) async {
    final text = message.trim();
    if (text.isEmpty && (attachmentPath == null || attachmentPath.isEmpty)) {
      return false;
    }

    try {
      if (attachmentPath != null && attachmentPath.isNotEmpty) {
        await ApiClient.instance.multipart(
          '/open-matches/$matchId/messages',
          fields: {if (text.isNotEmpty) 'message': text},
          files: [
            await ApiClient.instance.fileFromPath(
              'attachment',
              attachmentPath,
            ),
          ],
        );
      } else {
        await ApiClient.instance.post(
          '/open-matches/$matchId/messages',
          body: {'message': text},
        );
      }
      return true;
    } on ApiException {
      return false;
    }
  }

  /// Notifier untuk sinkronisasi data match antar halaman.
  static final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

  static void bumpData() => dataRevision.value++;
}
