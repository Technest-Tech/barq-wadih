import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/fcm_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
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

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(notificationRepositoryProvider).fetchUnreadCount();
});

// ── Unread-state synchronisation ──────────────────────────────────────────────

/// Re-read the unread count and mirror it onto the app-icon badge.
///
/// Every place that marks notifications read has to run this, otherwise the
/// bell keeps its old number and — on iOS — the icon keeps the badge the push
/// payload set, since only another push could ever move it.
Future<void> refreshUnreadNotifications(WidgetRef ref) async {
  // Signed-out sessions have no notifications; asking would only 401.
  if (ref.read(authProvider) is! AuthAuthenticated) {
    await FCMService.instance.setAppBadge(0);
    return;
  }
  try {
    // refresh(...future) both re-runs the provider — so a watching bell
    // rebuilds — and hands back the fresh value for the icon badge, in a
    // single round-trip.
    final count = await ref.refresh(unreadNotificationCountProvider.future);
    await FCMService.instance.setAppBadge(count);
  } catch (_) {
    // A stale badge must never break the screen that triggered the refresh.
  }
}

/// Clear the unread notifications that pointed at one subject, then resync.
///
/// Opening the conversation or the ad a notification was about is the user
/// telling us they have seen it — so it must not stay unread behind them.
Future<void> clearNotificationsFor(
  WidgetRef ref, {
  String? type,
  String? conversationId,
  int? adId,
}) async {
  if (ref.read(authProvider) is! AuthAuthenticated) return;
  try {
    final cleared = await ref
        .read(notificationRepositoryProvider)
        .markReadFor(type: type, conversationId: conversationId, adId: adId);
    if (cleared == 0) return;
  } catch (_) {
    return;
  }
  await refreshUnreadNotifications(ref);
}
