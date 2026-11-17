/// Ulasan pemain untuk sebuah lapangan.
///
/// Dipetakan dari `reviews[]` pada payload lapangan (`courtPayload`).
class ReviewModel {
  final int id;
  final int rating;
  final String message;
  final String? replyMessage;
  final String userName;
  final String? userPhotoUrl;
  final DateTime? createdAt;

  const ReviewModel({
    required this.id,
    required this.rating,
    required this.message,
    this.replyMessage,
    this.userName = 'Pemain ArenaSports',
    this.userPhotoUrl,
    this.createdAt,
  });

  String get initial {
    final name = userName.trim();
    if (name.isEmpty) return 'P';
    return name.substring(0, 1).toUpperCase();
  }

  String get relativeTime {
    final date = createdAt;
    if (date == null) return '-';

    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inHours < 1) return '${difference.inMinutes} menit lalu';
    if (difference.inDays < 1) return '${difference.inHours} jam lalu';
    if (difference.inDays < 30) return '${difference.inDays} hari lalu';
    if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} bulan lalu';
    }
    return '${(difference.inDays / 365).floor()} tahun lalu';
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: _int(json['id']),
      rating: _int(json['rating']),
      message: _string(json['message']) ?? '',
      replyMessage: _string(json['reply_message']),
      userName: _string(json['user_name']) ?? 'Pemain ArenaSports',
      userPhotoUrl: _string(json['user_photo_url']),
      createdAt: _date(json['created_at']),
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
