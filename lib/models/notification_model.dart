class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String time;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? url;

  NotificationModel({
    String? id,
    required this.title,
    required this.message,
    String? time,
    this.type = 'info',
    this.isRead = false,
    DateTime? createdAt,
    this.url,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       time = time ?? _formatTime(createdAt ?? DateTime.now());

  static String _formatTime(DateTime value) {
    final now = DateTime.now();
    if (value.day == now.day &&
        value.month == now.month &&
        value.year == now.year) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    if (value.year == now.year) {
      return '${value.day}/${value.month}';
    }
    return '${value.day}/${value.month}/${value.year}';
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    final createdAt = rawCreatedAt == null
        ? DateTime.now()
        : DateTime.tryParse(rawCreatedAt.toString())?.toLocal() ??
              DateTime.now();

    return NotificationModel(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? 'Notifikasi',
      message: json['message']?.toString() ?? '',
      time: json['time']?.toString(),
      type: json['type']?.toString() ?? 'info',
      isRead: json['is_read'] == true || json['isRead'] == true,
      createdAt: createdAt,
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'time': time,
    'type': type,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
    'url': url,
  };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id,
    title: title,
    message: message,
    time: time,
    type: type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    url: url,
  );
}
