class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id:        json['id'] as int,
      type:      json['type'] as String? ?? '',
      title:     json['title'] as String? ?? '',
      body:      json['body'] as String?,
      data:      json['data'] as Map<String, dynamic>?,
      isRead:    json['is_read'] as bool? ?? false,
      readAt:    json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Human-readable relative time in Arabic.
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1)  return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7)     return 'منذ ${diff.inDays} ي';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Icon string based on notification type.
  String get icon {
    switch (type) {
      case 'new_ad_followed': return '📢';
      case 'new_message':     return '💬';
      case 'new_rating':      return '⭐';
      default:                return '🔔';
    }
  }
}
