import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/chat_providers.dart';
import '../../domain/chat_models.dart';

const _kHeaderBlue = Color(0xFF1B4FE4);
const _kBgLight    = Color(0xFFF5F7FB);

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: _kBgLight,
        appBar: _buildAppBar(),
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

    // Ensure Firebase is signed in before starting the Firestore stream.
    // Without auth, the security rule (request.auth != null) rejects every read.
    final firebaseAuth = ref.watch(firebaseChatAuthProvider);
    if (firebaseAuth.isLoading) {
      return Scaffold(backgroundColor: _kBgLight, appBar: _buildAppBar(), body: _buildSkeleton());
    }
    if (firebaseAuth.hasError) {
      return Scaffold(
        backgroundColor: _kBgLight,
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'تعذّر الاتصال بخدمة الرسائل',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(firebaseChatAuthProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Use the Firebase UID for the Firestore query (participantUids field).
    // myId (backend integer string) is kept for display logic (peerNames, unreadCount maps).
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final convAsync = ref.watch(conversationsStreamProvider(myUid));

    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: convAsync.when(
              loading: () => _buildSkeleton(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('خطأ في تحميل الرسائل: $e',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center),
                ),
              ),
              data: (conversations) {
                final filtered = _filter(conversations);
                if (conversations.isEmpty) return _buildEmptyState();
                if (filtered.isEmpty) return _buildNoMatchState();
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 76, endIndent: 0),
                  itemBuilder: (context, index) {
                    final conv = filtered[index];
                    return _ConversationTile(conv: conv, myId: myId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<ConversationModel> _filter(List<ConversationModel> conversations) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return conversations;
    return conversations.where((c) {
      final hay = '${c.adTitle} ${c.lastMessage ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _kHeaderBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'الرسائل',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: 0.2,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: _kHeaderBlue,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'بحث',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          ),
        ),
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

  Widget _buildNoMatchState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'لا توجد نتائج لبحثك',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
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
    final unread      = conv.myUnreadCount(myId);
    final isMe        = conv.lastMessageSenderId == myId;
    final lastTime    = conv.lastMessageAt != null ? _relTime(conv.lastMessageAt!) : '';
    final displayName = conv.otherName(myId);
    final avatarUrl   = conv.otherAvatar(myId);
    final initial     = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();

    return InkWell(
      onTap: () => context.push(AppRoutes.conversationPath(conv.id)),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar (circular)
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarFallback(initial),
                        )
                      : _avatarFallback(initial),
                ),
                if (unread > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _kHeaderBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A1628),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        lastTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: unread > 0 ? _kHeaderBlue : Colors.grey[500],
                          fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Read receipt for outgoing last message
                      if (isMe) ...[
                        Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          '${isMe ? '' : ''}${conv.lastMessage ?? 'بدأت محادثة جديدة'}',
                          style: TextStyle(
                            fontSize: 12.5,
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
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kHeaderBlue,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Container(
      width: 48,
      height: 48,
      color: const Color(0xFFE7EAEF),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return '${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return '${diff.inHours} ساعة';
    if (diff.inDays < 7) return '${diff.inDays} يوم';
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
          _circle(48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(11, double.infinity),
                const SizedBox(height: 8),
                _box(11, 160),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEEEEEE),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _box(double h, double w) {
    return Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
