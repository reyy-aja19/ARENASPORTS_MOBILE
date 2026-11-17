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
  final String? imageUrl;
  final bool joined;
  final bool isHost;
  final bool isFull;
  final bool chatAvailable;

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
    this.imageUrl,
    this.joined = false,
    this.isHost = false,
    this.isFull = false,
    this.chatAvailable = false,
  });

  bool get isTournament => eventType == 'tournament';

  bool get canChat => joined || isHost;

  bool get isRegistered => joined || isHost;

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final jumlahPemain = _int(json['jumlah_pemain']);
    final jumlahBergabung = _int(json['jumlah_bergabung']);

    return MatchModel(
      id: _int(json['id']),
      bookingId: json['booking_id'] == null ? null : _int(json['booking_id']),
      title: _string(json['title']) ?? 'Open Match',
      jenis: _string(json['jenis']) ?? 'Olahraga',
      tanggal: _string(json['tanggal']) ?? '',
      startTime: _string(json['start_time']) ?? '',
      endTime: _string(json['end_time']) ?? '',
      jumlahPemain: jumlahPemain,
      jumlahBergabung: jumlahBergabung,
      status: _string(json['status']) ?? 'Open',
      deskripsi: _string(json['deskripsi']) ?? '',
      eventType: _string(json['event_type']) ?? 'open_match',
      organizer: _string(json['organizer']) ?? 'Pengguna',
      registrationFee: _int(json['registration_fee']),
      prize: _string(json['prize']) ?? '',
      fieldId: _int(json['field_id']),
      fieldName: _string(json['field_name']) ?? '',
      venueName: _string(json['venue_name']) ?? '',
      imageUrl: _string(json['image_url']),
      joined: json['joined'] == true,
      isHost: json['is_host'] == true,
      isFull: json['is_full'] == true || jumlahBergabung >= jumlahPemain,
      chatAvailable: json['chat_available'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'booking_id': bookingId,
    'title': title,
    'jenis': jenis,
    'tanggal': tanggal,
    'start_time': startTime,
    'end_time': endTime,
    'jumlah_pemain': jumlahPemain,
    'jumlah_bergabung': jumlahBergabung,
    'status': status,
    'deskripsi': deskripsi,
    'event_type': eventType,
    'organizer': organizer,
    'registration_fee': registrationFee,
    'prize': prize,
    'field_id': fieldId,
    'field_name': fieldName,
    'venue_name': venueName,
    'image_url': imageUrl,
    'joined': joined,
    'is_host': isHost,
    'is_full': isFull,
    'chat_available': chatAvailable,
  };
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _string(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
