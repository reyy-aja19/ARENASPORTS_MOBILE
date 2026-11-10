class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String time;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    String? id,
    required this.title,
    required this.message,
    String? time,
    this.type = 'info',
    this.isRead = false,
    DateTime? createdAt,
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
    final createdAt = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    return NotificationModel(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      time: json['time']?.toString(),
      type: json['type']?.toString() ?? 'info',
      isRead: json['isRead'] == true,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'time': time,
    'type': type,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id,
    title: title,
    message: message,
    time: time,
    type: type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
