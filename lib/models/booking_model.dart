import 'field_model.dart';

class PaymentModel {
  final int id;
  final String method;
  final int amount;
  final String status;
  final DateTime? paidAt;
  final String? transactionId;
  final String? midtransOrderId;
  final bool hasSnapToken;
  final int? bookingExtensionId;

  const PaymentModel({
    required this.id,
    required this.method,
    required this.amount,
    required this.status,
    this.paidAt,
    this.transactionId,
    this.midtransOrderId,
    this.hasSnapToken = false,
    this.bookingExtensionId,
  });

  bool get isPaid => const {
    'lunas',
    'selesai',
    'settlement',
    'capture',
    'success',
  }.contains(status.toLowerCase());

  bool get isCash => method.toLowerCase() == 'cash';

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: _int(json['id']),
      method: _string(json['method']) ?? 'Cash',
      amount: _int(json['amount']),
      status: _string(json['status']) ?? 'Menunggu',
      paidAt: _date(json['paid_at']),
      transactionId: _string(json['transaction_id']),
      midtransOrderId: _string(json['midtrans_order_id']),
      hasSnapToken: json['has_snap_token'] == true,
      bookingExtensionId: json['booking_extension_id'] == null
          ? null
          : _int(json['booking_extension_id']),
    );
  }
}

class BookingExtensionModel {
  final int id;
  final int hours;
  final String previousEndTime;
  final String newEndTime;
  final int amount;
  final String status;
  final String? note;
  final PaymentModel? payment;

  const BookingExtensionModel({
    required this.id,
    required this.hours,
    required this.previousEndTime,
    required this.newEndTime,
    required this.amount,
    required this.status,
    this.note,
    this.payment,
  });

  factory BookingExtensionModel.fromJson(Map<String, dynamic> json) {
    return BookingExtensionModel(
      id: _int(json['id']),
      hours: _int(json['hours']),
      previousEndTime: _string(json['previous_end_time']) ?? '-',
      newEndTime: _string(json['new_end_time']) ?? '-',
      amount: _int(json['amount']),
      status: _string(json['status']) ?? 'Menunggu',
      note: _string(json['note']),
      payment: json['payment'] is Map
          ? PaymentModel.fromJson(
              Map<String, dynamic>.from(json['payment'] as Map),
            )
          : null,
    );
  }
}

class BookingModel {
  final int id;
  final String status;
  final String effectiveStatus;
  final String paymentMethod;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final int hours;
  final int totalPrice;
  final DateTime? createdAt;
  final CourtModel? court;
  final PaymentModel? payment;
  final bool isPaid;
  final int? openMatchId;
  final bool hasReview;
  final String? paymentProofUrl;
  final List<BookingExtensionModel> extensions;

  const BookingModel({
    required this.id,
    required this.status,
    required this.effectiveStatus,
    required this.paymentMethod,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.hours,
    required this.totalPrice,
    this.createdAt,
    this.court,
    this.payment,
    this.isPaid = false,
    this.openMatchId,
    this.hasReview = false,
    this.paymentProofUrl,
    this.extensions = const [],
  });

  bool get isActive {
    final value = effectiveStatus.toLowerCase();
    return value == 'menunggu' || value == 'dp' || value == 'lunas';
  }

  bool get isCompleted {
    final value = effectiveStatus.toLowerCase();
    return value == 'selesai' ||
        value == 'dibatalkan' ||
        value == 'batal' ||
        value == 'expired';
  }

  bool get isCancelled {
    final value = effectiveStatus.toLowerCase();
    return value == 'dibatalkan' || value == 'batal' || value == 'expired';
  }

  String get courtName =>
      court?.name ?? court?.displayName ?? 'Lapangan ArenaSports';

  String get venueName => court?.venueName ?? 'Venue ArenaSports';

  String get imageUrl => court?.imageUrl ?? '';

  String get venueAddress => court?.venueAddress ?? '';

  /// Semua foto lapangan/venue pada booking ini (foto utama + galeri).
  List<String> get galleryImages {
    final images = <String>[];
    void add(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty || images.contains(text)) return;
      images.add(text);
    }

    add(imageUrl);
    for (final image in court?.galleryImages ?? const <String>[]) {
      add(image);
    }
    return images;
  }

  String get dateLabel => bookingDate;

  String get timeLabel => '$startTime - $endTime';

  String get statusLabel {
    switch (effectiveStatus.toLowerCase()) {
      case 'menunggu':
        return 'Menunggu Pembayaran';
      case 'dp':
        return 'DP Dibayar';
      case 'lunas':
        return 'Lunas';
      case 'selesai':
        return 'Selesai';
      case 'dibatalkan':
      case 'batal':
        return 'Dibatalkan';
      case 'expired':
        return 'Kedaluwarsa';
      default:
        return effectiveStatus;
    }
  }

  bool get canCreateMatch =>
      isPaid && isActive && openMatchId == null && !isCancelled;

  bool get canReview =>
      isPaid &&
      (status.toLowerCase() == 'lunas' ||
          effectiveStatus.toLowerCase() == 'selesai') &&
      !hasReview;

  bool get canExtend =>
      isPaid && status.toLowerCase() == 'lunas' && isActive;

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: _int(json['id']),
      status: _string(json['status']) ?? 'Menunggu',
      effectiveStatus: _string(json['effective_status']) ?? _string(json['status']) ?? 'Menunggu',
      paymentMethod: _string(json['payment_method']) ?? 'Cash',
      bookingDate: _string(json['booking_date']) ?? '-',
      startTime: _string(json['start_time']) ?? '-',
      endTime: _string(json['end_time']) ?? '-',
      hours: _int(json['hours']),
      totalPrice: _int(json['total_price']),
      createdAt: _date(json['created_at']),
      court: json['court'] is Map
          ? CourtModel.fromJson(Map<String, dynamic>.from(json['court'] as Map))
          : null,
      payment: json['payment'] is Map
          ? PaymentModel.fromJson(
              Map<String, dynamic>.from(json['payment'] as Map),
            )
          : null,
      isPaid: json['is_paid'] == true,
      openMatchId: json['open_match_id'] == null
          ? null
          : _int(json['open_match_id']),
      hasReview: json['has_review'] == true,
      paymentProofUrl: _string(json['payment_proof_url']) ??
          _string(json['payment_proof']) ??
          _string(json['proof_url']) ??
          _string(json['bukti_pembayaran']) ??
          (json['payment'] is Map
              ? (_string((json['payment'] as Map)['payment_proof_url']) ??
                  _string((json['payment'] as Map)['payment_proof']) ??
                  _string((json['payment'] as Map)['proof_url']))
              : null),
      extensions: (json['extensions'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) =>
                BookingExtensionModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _string(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
