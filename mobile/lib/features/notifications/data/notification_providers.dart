import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/notification_model.dart';
import 'notification_repository.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(dioProvider));
});

// ── Notifications list ────────────────────────────────────────────────────────

final notificationsListProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) {
  return ref.watch(notificationRepositoryProvider).fetchNotifications();
});

// ── Unread count ──────────────────────────────────────────────────────────────

final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) {
  return ref.watch(notificationRepositoryProvider).fetchUnreadCount();
});
