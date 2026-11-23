import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/booking_model.dart';
import '../models/field_model.dart';
import '../models/notification_model.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Satu slot jam pada jadwal lapangan.
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.startTime,
    required this.endTime,
    required this.available,
  });

  final String startTime;
  final String endTime;
  final bool available;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      available: json['available'] == true,
    );
  }
}

class AvailabilityData {
  const AvailabilityData({
    required this.date,
    required this.opening,
    required this.closing,
    required this.slots,
    required this.price,
  });

  final String date;
  final String opening;
  final String closing;
  final List<AvailabilitySlot> slots;
  final int price;

  factory AvailabilityData.fromJson(Map<String, dynamic> json) {
    return AvailabilityData(
      date: json['date']?.toString() ?? '',
      opening: json['opening']?.toString() ?? '07:00',
      closing: json['closing']?.toString() ?? '23:00',
      slots: (json['slots'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                AvailabilitySlot.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      price: _asInt(json['price']),
    );
  }
}

/// Data transaksi Midtrans Snap dari backend.
class SnapTransaction {
  const SnapTransaction({
    required this.paymentId,
    required this.orderId,
    required this.snapToken,
    required this.redirectUrl,
    required this.clientKey,
    required this.isProduction,
  });

  final int paymentId;
  final String orderId;
  final String snapToken;
  final String redirectUrl;
  final String clientKey;
  final bool isProduction;

  factory SnapTransaction.fromJson(Map<String, dynamic> json) {
    return SnapTransaction(
      paymentId: _asInt(json['payment_id']),
      orderId: json['order_id']?.toString() ?? '',
      snapToken: json['snap_token']?.toString() ?? '',
      redirectUrl: json['redirect_url']?.toString() ?? '',
      clientKey: json['client_key']?.toString() ?? '',
      isProduction: json['is_production'] == true,
    );
  }
}

class BookingCreation {
  const BookingCreation({required this.booking, required this.requiresPayment});

  final BookingModel booking;
  final bool requiresPayment;
}

class PaymentStatus {
  const PaymentStatus({
    required this.payment,
    required this.booking,
    required this.isPaid,
  });

  final PaymentModel? payment;
  final BookingModel? booking;
  final bool isPaid;

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    return PaymentStatus(
      payment: json['payment'] is Map
          ? PaymentModel.fromJson(
              Map<String, dynamic>.from(json['payment'] as Map),
            )
          : null,
      booking: json['booking'] is Map
          ? BookingModel.fromJson(
              Map<String, dynamic>.from(json['booking'] as Map),
            )
          : null,
      isPaid: json['is_paid'] == true,
    );
  }
}

class TicketData {
  const TicketData({
    required this.booking,
    required this.ticketCode,
    required this.qrPayload,
  });

  final BookingModel booking;
  final String ticketCode;
  final String qrPayload;
}

class RewardsData {
  const RewardsData({
    required this.points,
    required this.rewards,
    required this.redemptions,
  });

  final int points;
  final List<Map<String, dynamic>> rewards;
  final List<Map<String, dynamic>> redemptions;
}

/// Riwayat pembayaran dari GET /payments.
class PaymentHistory {
  const PaymentHistory({required this.payments, required this.total});

  final List<PaymentModel> payments;
  final int total;
}

/// Seluruh permintaan HTTP ke API Laravel ARENASPORTS untuk role user.
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  Future<Map<String, dynamic>> home({double? lat, double? lng}) async {
    final data = await ApiClient.instance.get(
      '/home',
      query: _coords(lat, lng),
    );
    final map = _map(data);
    final user = map['user'];
    if (user is Map) {
      await SessionService.updateUser(Map<String, dynamic>.from(user));
    }
    return map;
  }

  Future<List<FieldModel>> venues({
    String? query,
    double? lat,
    double? lng,
  }) async {
    final params = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      ..._coords(lat, lng),
    };
    final data = await ApiClient.instance.get(
      '/venues',
      query: params.isEmpty ? null : params,
      auth: false,
    );
    return _map(data)['venues'] is List
        ? (_map(data)['venues'] as List)
              .whereType<Map>()
              .map(
                (item) => FieldModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <FieldModel>[];
  }

  /// Venue berdekatan dengan koordinat pengguna (GET /chatbot/nearby-venues).
  Future<List<FieldModel>> nearbyVenues({double? lat, double? lng}) async {
    final data = await ApiClient.instance.get(
      '/chatbot/nearby-venues',
      query: _coords(lat, lng),
      auth: false,
    );
    final map = _map(data);
    return (map['venues'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => FieldModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<FieldModel> venueDetail(
    int venueId, {
    double? lat,
    double? lng,
  }) async {
    final data = await ApiClient.instance.get(
      '/venues/$venueId',
      query: _coords(lat, lng),
      auth: false,
    );
    return FieldModel.fromJson(_map(_map(data)['venue']));
  }

  Future<List<CourtModel>> courts({
    int? venueId,
    String? query,
    double? lat,
    double? lng,
  }) async {
    final params = <String, String>{
      if (venueId != null) 'venue_id': '$venueId',
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      ..._coords(lat, lng),
    };
    final data = await ApiClient.instance.get(
      '/courts',
      query: params.isEmpty ? null : params,
      auth: false,
    );
    final list = _map(data)['courts'];
    return list is List
        ? list
              .whereType<Map>()
              .map(
                (item) => CourtModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <CourtModel>[];
  }

  Future<CourtModel> courtDetail(int courtId) async {
    final data = await ApiClient.instance.get('/courts/$courtId', auth: false);
    return CourtModel.fromJson(_map(_map(data)['court']));
  }

  Future<AvailabilityData> availability(int courtId, String date) async {
    final data = await ApiClient.instance.get(
      '/courts/$courtId/availability',
      query: {'date': date},
      auth: false,
    );
    return AvailabilityData.fromJson(_map(data));
  }

  Future<BookingCreation> createBooking({
    required int courtId,
    required String date,
    required String startTime,
    required int hours,
    required String paymentMethod,
  }) async {
    final data = await ApiClient.instance.post(
      '/bookings',
      body: {
        'lapangan_id': courtId,
        'booking_date': date,
        'start_time': startTime,
        'hours': hours,
        'payment_method': paymentMethod,
      },
    );
    final map = _map(data);
    return BookingCreation(
      booking: BookingModel.fromJson(_map(map['booking'])),
      requiresPayment: map['requires_payment'] == true,
    );
  }

  Future<List<BookingModel>> bookings({String scope = 'all'}) async {
    final data = await ApiClient.instance.get(
      '/bookings',
      query: {'scope': scope},
    );
    return _bookingList(_map(data)['bookings']);
  }

  Future<BookingModel> bookingDetail(int bookingId) async {
    final data = await ApiClient.instance.get('/bookings/$bookingId');
    return BookingModel.fromJson(_map(_map(data)['booking']));
  }

  Future<List<BookingModel>> eligibleBookings() async {
    final data = await ApiClient.instance.get('/bookings/eligible');
    return _bookingList(_map(data)['bookings']);
  }

  Future<void> submitReview(
    int bookingId, {
    required int rating,
    required String message,
  }) async {
    await ApiClient.instance.post(
      '/bookings/$bookingId/review',
      body: {'rating': rating, 'message': message},
    );
  }

  Future<BookingExtensionModel> requestExtension(
    int bookingId, {
    required int hours,
  }) async {
    final data = await ApiClient.instance.post(
      '/bookings/$bookingId/extension',
      body: {'hours': hours},
    );
    return BookingExtensionModel.fromJson(_map(_map(data)['extension']));
  }

  Future<TicketData> ticket(int bookingId) async {
    final data = await ApiClient.instance.get('/bookings/$bookingId/ticket');
    final map = _map(data);
    return TicketData(
      booking: BookingModel.fromJson(_map(map['booking'])),
      ticketCode: map['ticket_code']?.toString() ?? '',
      qrPayload: map['qr_payload']?.toString() ?? '',
    );
  }

  Future<SnapTransaction> checkoutBooking(int bookingId) async {
    final data = await ApiClient.instance.get('/bookings/$bookingId/payment');
    return SnapTransaction.fromJson(_map(data));
  }

  Future<SnapTransaction> checkoutExtension(int extensionId) async {
    final data = await ApiClient.instance.get(
      '/extensions/$extensionId/payment',
    );
    return SnapTransaction.fromJson(_map(data));
  }

  Future<PaymentStatus> paymentStatus(int paymentId) async {
    final data = await ApiClient.instance.get('/payments/$paymentId/status');
    return PaymentStatus.fromJson(_map(data));
  }

  /// Riwayat pembayaran per pengguna (GET /payments).
  Future<PaymentHistory> paymentHistory() async {
    final data = await ApiClient.instance.get('/payments');
    final map = _map(data);
    return PaymentHistory(
      payments: (map['payments'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) => PaymentModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      total: _int(map['total']),
    );
  }

  Future<void> cancelBooking(int bookingId) async {
    await ApiClient.instance.post('/bookings/$bookingId/cancel');
  }

  Future<RewardsData> rewards() async {
    final data = await ApiClient.instance.get('/rewards');
    final map = _map(data);
    return RewardsData(
      points: _int(map['points']),
      rewards: _mapList(map['rewards']),
      redemptions: _mapList(map['redemptions']),
    );
  }

  Future<Map<String, dynamic>> redeemReward(int rewardId) async {
    final data = await ApiClient.instance.post('/rewards/$rewardId/redeem');
    final map = _map(data);
    final points = _int(map['points']);
    await SessionService.updateUser({'points': points});
    return map;
  }

  Future<NotificationPage> notifications({
    int page = 1,
    int perPage = 30,
  }) async {
    final data = await ApiClient.instance.get(
      '/notifications',
      query: {'page': '$page', 'per_page': '$perPage'},
    );
    final map = _map(data);
    return NotificationPage(
      notifications: (map['notifications'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                NotificationModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      unreadCount: _int(map['unread_count']),
      currentPage: _int(map['current_page']),
      lastPage: _int(map['last_page']),
      total: _int(map['total']),
    );
  }

  Future<void> markNotificationRead(String id) async {
    await ApiClient.instance.post('/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await ApiClient.instance.post('/notifications/read-all');
  }

  Future<void> deleteNotification(String id) async {
    await ApiClient.instance.delete('/notifications/$id');
  }

  Future<void> clearNotifications() async {
    await ApiClient.instance.delete('/notifications');
  }

  Future<Map<String, dynamic>> profile() async {
    final data = await ApiClient.instance.get('/profile');
    final map = _map(data);
    final user = map['user'];
    if (user is Map) {
      await SessionService.updateUser(Map<String, dynamic>.from(user));
    }
    return map;
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? email,
    String? phone,
    String? photoPath,
    Uint8List? photoBytes,
    String? photoName,
    bool removePhoto = false,
  }) async {
    final files = <http.MultipartFile>[];
    if (photoBytes != null && photoBytes.isNotEmpty) {
      files.add(
        http.MultipartFile.fromBytes(
          'profile_photo',
          photoBytes,
          filename: photoName ?? 'profile.jpg',
        ),
      );
    } else if (photoPath != null && photoPath.isNotEmpty) {
      files.add(
        await ApiClient.instance.fileFromPath('profile_photo', photoPath),
      );
    }

    final data = await ApiClient.instance.multipart(
      '/profile',
      fields: {
        'name': name,
        'email': ?email,
        'phone': ?phone,
        if (removePhoto) 'remove_photo': true,
      },
      files: files,
    );
    final map = _map(data);
    final user = map['user'];
    if (user is Map) {
      await SessionService.updateUser(Map<String, dynamic>.from(user));
    }
    return map;
  }

  Future<Map<String, dynamic>> venueApplication() async {
    final data = await ApiClient.instance.get('/venue-application');
    return _map(data);
  }

  Future<Map<String, dynamic>> submitVenueApplication({
    required Map<String, dynamic> fields,
    Map<String, String> documentPaths = const {},
    List<String> courtPhotos = const [],
  }) async {
    final files = <http.MultipartFile>[];
    for (final entry in documentPaths.entries) {
      if (entry.value.isEmpty) continue;
      files.add(await ApiClient.instance.fileFromPath(entry.key, entry.value));
    }
    for (var index = 0; index < courtPhotos.length; index++) {
      final path = courtPhotos[index];
      if (path.isEmpty) continue;
      files.add(
        await ApiClient.instance.fileFromPath('court_photos[$index]', path),
      );
    }

    final data = await ApiClient.instance.multipart(
      '/venue-application',
      fields: fields,
      files: files,
    );
    return _map(data);
  }

  Future<Map<String, dynamic>> chatbot(
    String message, {
    double? latitude,
    double? longitude,
  }) async {
    final data = await ApiClient.instance.post(
      '/chatbot',
      auth: false,
      body: {
        'message': message,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
    return _map(data);
  }

  Map<String, String> _coords(double? lat, double? lng) {
    return {
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    };
  }

  List<BookingModel> _bookingList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => BookingModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _map(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class NotificationPage {
  const NotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<NotificationModel> notifications;
  final int unreadCount;
  final int currentPage;
  final int lastPage;
  final int total;
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
