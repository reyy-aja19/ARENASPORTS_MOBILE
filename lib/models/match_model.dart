class MatchModel {
  final int id;
  final int? bookingId;
  final String title;
  final String jenis;
  final String tanggal;
  final String startTime;
  final String endTime;
  final int jumlahPemain;
  final int jumlahBergabung;
  final String status;
  final String deskripsi;
  final String eventType;
  final String organizer;
  final int registrationFee;
  final String prize;
  final int fieldId;
  final String fieldName;
  final String venueName;
  final String venueAddress;
  final double? venueLatitude;
  final double? venueLongitude;
  final String? googleMapsUrl;
  final String? googleMapsEmbedUrl;
  final String contactPhone;
  final String contactWhatsapp;
  final String level;
  final int? biayaPerPemain;
  final bool isFree;
  final int? bookingTotalPrice;
  final int suggestedPricePerPlayer;
  final String? registrationDeadline;
  final bool isRegistered;
  final String? registrationStatus;
  final String? imageUrl;
  final bool joined;
  final bool isHost;
  final bool isFull;
  final bool chatAvailable;
  final bool hasEnded;

  const MatchModel({
    required this.id,
    this.bookingId,
    required this.title,
    required this.jenis,
    required this.tanggal,
    required this.startTime,
    required this.endTime,
    required this.jumlahPemain,
    required this.jumlahBergabung,
    required this.status,
    required this.deskripsi,
    this.eventType = 'open_match',
    this.organizer = 'Pengguna',
    this.registrationFee = 0,
    this.prize = '',
    this.fieldId = 0,
    this.fieldName = '',
    this.venueName = '',
    this.venueAddress = '',
    this.venueLatitude,
    this.venueLongitude,
    this.googleMapsUrl,
    this.googleMapsEmbedUrl,
    this.contactPhone = '',
    this.contactWhatsapp = '',
    this.level = '',
    this.biayaPerPemain,
    this.isFree = true,
    this.bookingTotalPrice,
    this.suggestedPricePerPlayer = 0,
    this.registrationDeadline,
    this.isRegistered = false,
    this.registrationStatus,
    this.imageUrl,
    this.joined = false,
    this.isHost = false,
    this.isFull = false,
    this.chatAvailable = false,
    this.hasEnded = false,
  });

  bool get isTournament => eventType.toLowerCase() == 'tournament';
  bool get isOpenMatch => !isTournament;

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final normalized = value?.toString().toLowerCase().trim();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    final biaya = json['biaya_per_pemain'];
    final parsedBiaya = biaya == null ? null : parseInt(biaya);

    return MatchModel(
      id: parseInt(json['id']),
      bookingId: json['booking_id'] == null ? null : parseInt(json['booking_id']),
      title: json['title']?.toString() ?? 'Open Match',
      jenis: json['jenis']?.toString() ?? '-',
      tanggal: json['tanggal']?.toString() ?? '-',
      startTime: json['start_time']?.toString() ?? '-',
      endTime: json['end_time']?.toString() ?? '-',
      jumlahPemain: parseInt(json['jumlah_pemain']),
      jumlahBergabung: parseInt(json['jumlah_bergabung']),
      status: json['status']?.toString() ?? 'Open',
      deskripsi: json['deskripsi']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? 'open_match',
      organizer: json['organizer']?.toString() ?? 'Pengguna',
      registrationFee: parseInt(json['registration_fee']),
      prize: json['prize']?.toString() ?? '',
      fieldId: parseInt(json['field_id']),
      fieldName: json['field_name']?.toString() ?? '',
      venueName: json['venue_name']?.toString() ?? '',
      venueAddress: json['venue_address']?.toString() ?? '',
      venueLatitude: parseDouble(json['venue_latitude']),
      venueLongitude: parseDouble(json['venue_longitude']),
      googleMapsUrl: json['google_maps_url']?.toString(),
      googleMapsEmbedUrl: json['google_maps_embed_url']?.toString(),
      contactPhone: json['contact_phone']?.toString() ?? '',
      contactWhatsapp: json['contact_whatsapp']?.toString() ?? '',
      level: json['level']?.toString() ?? '',
      biayaPerPemain: parsedBiaya,
      isFree: json['is_free'] == null
          ? (parsedBiaya == null || parsedBiaya <= 0)
          : parseBool(json['is_free']),
      bookingTotalPrice:
          json['booking_total_price'] == null ? null : parseInt(json['booking_total_price']),
      suggestedPricePerPlayer: parseInt(json['suggested_price_per_player']),
      registrationDeadline: json['registration_deadline']?.toString(),
      isRegistered: parseBool(json['is_registered'] ?? json['joined']),
      registrationStatus: json['registration_status']?.toString(),
      imageUrl: json['image_url']?.toString(),
      joined: parseBool(json['joined']),
      isHost: parseBool(json['is_host']),
      isFull: parseBool(json['is_full']),
      chatAvailable: parseBool(json['chat_available']),
      hasEnded: parseBool(json['has_ended']),
    );
  }
}
