import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/chat_providers.dart';
import '../../domain/chat_models.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('سجّل الدخول لعرض رسائلك',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push(AppRoutes.login),
                child: const Text('تسجيل الدخول'),
              ),
            ],
          ),
        ),
      );
    }

    final myId = user.id.toString();
    final convAsync = ref.watch(conversationsStreamProvider(myId));

    // Ensure Firebase is signed in for Firestore access
    ref.watch(firebaseChatAuthProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text(
          'الرسائل',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        centerTitle: false,
      ),
      body: convAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => Center(
          child: Text('خطأ في تحميل الرسائل: $e',
              style: const TextStyle(color: Colors.red)),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 76, endIndent: 0),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _ConversationTile(conv: conv, myId: myId);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد محادثات بعد',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ محادثة من صفحة أي إعلان',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
      itemBuilder: (_, __) => const _SkeletonTile(),
    );
  }
}

// ── Conversation tile ──────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conv, required this.myId});

  final ConversationModel conv;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final unread   = conv.myUnreadCount(myId);
    final isMe     = conv.lastMessageSenderId == myId;
    final lastTime = conv.lastMessageAt != null ? _relTime(conv.lastMessageAt!) : '';

    return InkWell(
      onTap: () => context.push(AppRoutes.conversationPath(conv.id)),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Ad thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: conv.adImage != null
                  ? Image.network(
                      conv.adImage!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.adTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A1628),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        lastTime,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${isMe ? 'أنت: ' : ''}${conv.lastMessage ?? 'بدأت محادثة جديدة'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: unread > 0
                                ? const Color(0xFF0A1628)
                                : Colors.grey[600],
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B4FE4),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left_rounded, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(child: Text('📦', style: TextStyle(fontSize: 24))),
    );
  }

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return '${diff.inMinutes} د';
    if (diff.inDays < 1) return '${diff.inHours} س';
    if (diff.inDays < 7) return '${diff.inDays} ي';
    return DateFormat('d/M').format(dt);
  }
}

// ── Skeleton tile ──────────────────────────────────────────────────────────────

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _box(52, 52, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(12, double.infinity),
                const SizedBox(height: 8),
                _box(12, 160),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(double h, double w, {double radius = 6}) {
    return Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
