class MatchModel {
  final int id;
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

  const MatchModel({
    required this.id,
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
  });

  bool get isTournament => eventType == 'tournament';

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'],
      title: json['title'] ?? '',
      jenis: json['jenis'] ?? '',
      tanggal: json['tanggal'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      jumlahPemain: json['jumlah_pemain'] ?? 0,
      jumlahBergabung: json['jumlah_bergabung'] ?? 0,
      status: json['status'] ?? 'Open',
      deskripsi: json['deskripsi'] ?? '',
      eventType: json['event_type'] ?? 'open_match',
      organizer: json['organizer'] ?? 'Pengguna',
      registrationFee: (json['registration_fee'] as num?)?.toInt() ?? 0,
      prize: json['prize']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
    };
  }
}
