import 'package:dio/dio.dart';

import '../domain/notification_model.dart';

class NotificationRepository {
  final Dio _dio;
  NotificationRepository(this._dio);

  /// Paginated list of notifications, newest first.
  Future<List<NotificationModel>> fetchNotifications({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'page': page},
    );
    final raw = res.data?['data'];
    final List<dynamic> data;
    if (raw is List) {
      data = raw;
    } else if (raw is Map) {
      // Paginated wrapper: { data: { data: [...], meta: {...} } }
      data = raw['data'] as List<dynamic>? ?? [];
    } else {
      data = [];
    }
    return data
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mark a single notification as read.
  Future<void> markRead(int id) async {
    await _dio.post<void>('/notifications/$id/read');
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    await _dio.post<void>('/notifications/read-all');
  }

  /// Mark the unread notifications about one subject as read.
  ///
  /// Opening a conversation or an ad clears the notifications that pointed at
  /// it — the client knows the subject, never the notification row ids, so the
  /// backend resolves the filter. Returns the number of rows cleared.
  Future<int> markReadFor({
    String? type,
    String? conversationId,
    int? adId,
  }) async {
    if (type == null && conversationId == null && adId == null) return 0;

    final res = await _dio.post<Map<String, dynamic>>(
      '/notifications/read-by',
      data: {
        if (type != null) 'type': type,
        if (conversationId != null) 'conversation_id': conversationId,
        if (adId != null) 'ad_id': adId,
      },
    );
    return (res.data?['data']?['updated'] as num?)?.toInt() ?? 0;
  }

  /// Get unread count.
  Future<int> fetchUnreadCount() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );
    return (res.data?['data']?['count'] as num?)?.toInt() ?? 0;
  }

  /// Register device FCM token.
  Future<void> registerDevice({
    required String fcmToken,
    required String deviceType, // 'ios', 'android', 'web'
    String? deviceName,
  }) async {
    await _dio.post<void>(
      '/devices',
      data: {
        'fcm_token': fcmToken,
        'device_type': deviceType,
        'device_name': deviceName,
      },
    );
  }

  /// Deactivate device token on logout.
  Future<void> deactivateDevice(String fcmToken) async {
    await _dio.delete<void>('/devices', data: {'fcm_token': fcmToken});
  }
}
