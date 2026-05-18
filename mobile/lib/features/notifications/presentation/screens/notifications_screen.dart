import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/notification_providers.dart';
import '../../domain/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        title: const Text('الإشعارات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('تعيين الكل مقروء',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmpty();
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsListProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) => _NotificationTile(
                notification: notifications[i],
                onTap: () => _handleTap(notifications[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_outlined, size: 72,
              color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('لا توجد إشعارات',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              )),
          const SizedBox(height: 8),
          Text('ستظهر هنا إشعاراتك عند وصولها',
              style: TextStyle(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {}
  }

  Future<void> _handleTap(NotificationModel n) async {
    // Mark as read
    if (!n.isRead) {
      try {
        await ref.read(notificationRepositoryProvider).markRead(n.id);
        ref.invalidate(notificationsListProvider);
        ref.invalidate(unreadNotificationCountProvider);
      } catch (_) {}
    }

    // Navigate based on type
    final data = n.data ?? {};
    if (!mounted) return;
    switch (data['type']) {
      case 'new_ad':
        if (data['ad_id'] != null) {
          context.push('/ads/${data['ad_id']}');
        }
        break;
      case 'chat':
        if (data['conversation_id'] != null) {
          context.push('/messages/${data['conversation_id']}');
        }
        break;
      case 'rating':
        if (data['ad_id'] != null) {
          context.push('/ads/${data['ad_id']}');
        }
        break;
    }
  }
}

// ── Notification tile widget ────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.white
              : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE2E8F0)
                : const Color(0xFFC7D2FE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(notification.icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    notification.title,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                      color: const Color(0xFF0A1628),
                    ),
                  ),
                  if (notification.body != null && notification.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.body!,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    notification.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            // Unread dot
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
