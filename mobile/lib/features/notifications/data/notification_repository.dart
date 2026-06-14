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
