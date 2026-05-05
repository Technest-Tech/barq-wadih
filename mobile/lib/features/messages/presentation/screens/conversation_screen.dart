import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/chat_providers.dart';
import '../../domain/chat_models.dart';
import '../widgets/chat_background.dart';

const _kHeaderBlue   = Color(0xFF1B4FE4);
const _kBubbleSent   = Color(0xFFDCF8C6); // WhatsApp green
const _kBubbleRecv   = Colors.white;
const _kInputBg      = Color(0xFFF0F2F5);
const _kTextPrimary  = Color(0xFF0A1628);
const _kTickRead     = Color(0xFF1B4FE4);

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _uploading = false;
  Map<String, dynamic>? _convMeta;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConvMeta();
      _markRead();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConvMeta() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      if (mounted && snap.exists) {
        setState(() => _convMeta = snap.data());
      }
    } catch (_) {/* swallow */}
  }

  Future<void> _markRead() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(chatRepositoryProvider).markAsRead(
      conversationId: widget.conversationId,
      myId: user.id.toString(),
    );
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _textController.clear();

    await ref.read(chatRepositoryProvider).sendMessage(
      conversationId: widget.conversationId,
      myId:           user.id.toString(),
      myUid:          _firebaseUid(),
      text:           text,
    );

    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      await ref.read(chatRepositoryProvider).sendImage(
        conversationId: widget.conversationId,
        myId:           user.id.toString(),
        myUid:          _firebaseUid(),
        imageFile:      File(picked.path),
      );
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _firebaseUid() {
    return FirebaseAuth.instance.currentUser?.uid
        ?? 'user_${ref.read(currentUserProvider)?.id ?? 0}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final myId = user?.id.toString() ?? '';

    final firebaseAuth = ref.watch(firebaseChatAuthProvider);
    if (firebaseAuth.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFECE5DD),
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (firebaseAuth.hasError) {
      return Scaffold(
        backgroundColor: const Color(0xFFECE5DD),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('تعذّر تحميل الرسائل',
                  style: TextStyle(color: Colors.grey[700], fontSize: 15)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(firebaseChatAuthProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final msgsAsync = ref.watch(messagesStreamProvider(widget.conversationId));

    ref.listen(messagesStreamProvider(widget.conversationId), (_, __) {
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: _buildAppBar(),
      body: ChatBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: msgsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error:   (e, _) => Center(child: Text('خطأ: $e')),
                  data:    (messages) => _buildMessageList(messages, myId),
                ),
              ),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(List<MessageModel> messages, String myId) {
    if (messages.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ابدأ المحادثة!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kTextPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'لا توجد رسائل بعد',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg  = messages[index];
        final isMe = msg.senderId == myId;
        final showSep = index == 0 ||
            !_sameDay(messages[index - 1].createdAt, msg.createdAt);

        return Column(
          children: [
            if (showSep) _DateSeparator(date: msg.createdAt),
            _MessageBubble(msg: msg, isMe: isMe),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final myId = ref.read(currentUserProvider)?.id.toString() ?? '';
    final participantIds = List<String>.from(
        (_convMeta?['participantIds'] as List<dynamic>?) ?? []);
    final otherId = participantIds.firstWhere((id) => id != myId, orElse: () => '');

    final peerNames   = Map<String, String>.from(
        (_convMeta?['peerNames']   as Map<dynamic, dynamic>? ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())));
    final peerAvatars = Map<String, String?>.from(
        (_convMeta?['peerAvatars'] as Map<dynamic, dynamic>? ?? {})
            .map((k, v) => MapEntry(k.toString(), v?.toString())));

    final displayName = peerNames[otherId]
        ?? (_convMeta?['adTitle'] as String?)
        ?? 'المحادثة';
    final avatarUrl   = peerAvatars[otherId]
        ?? (_convMeta?['adImage'] as String?);
    final initial     = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();

    return AppBar(
      backgroundColor: _kHeaderBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Row(
        children: [
          // Peer avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'برق واضح',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
          tooltip: 'المزيد',
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: _kInputBg,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mic FAB on the leading edge (left in RTL appears at start)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (_, value, __) {
              final hasText = value.text.trim().isNotEmpty;
              if (hasText) {
                return GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: _kHeaderBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x441B4FE4),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                );
              }
              return Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: _kHeaderBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 22),
              );
            },
          ),
          const SizedBox(width: 8),

          // Pill-shaped input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Camera button
                  IconButton(
                    icon: _uploading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.camera_alt_outlined, color: Colors.grey[600]),
                    onPressed: _uploading ? null : _pickImage,
                    splashRadius: 22,
                  ),
                  // Attachment button
                  IconButton(
                    icon: Icon(Icons.attach_file_rounded, color: Colors.grey[600]),
                    onPressed: _uploading ? null : _pickImage,
                    splashRadius: 22,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg, required this.isMe});

  final MessageModel msg;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(msg.createdAt);

    return Align(
      // RTL: own messages render on the right (centerRight); peer on the left
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? _kBubbleSent : _kBubbleRecv,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(12),
            topRight:    const Radius.circular(12),
            bottomLeft:  isMe ? const Radius.circular(12) : const Radius.circular(2),
            bottomRight: isMe ? const Radius.circular(2)  : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.isImage && msg.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    msg.imageUrl!,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            width: 220, height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
                )
              else
                Text(
                  msg.text,
                  style: const TextStyle(
                    color: _kTextPrimary,
                    fontSize: 14.5,
                    height: 1.45,
                  ),
                ),

              // Meta row: time + read receipt for own messages
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg.isRead ? Icons.done_all_rounded : Icons.check_rounded,
                        size: 14,
                        color: msg.isRead ? _kTickRead : Colors.grey[500],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date separator ─────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now  = DateTime.now();
    final diff = now.difference(date).inDays;
    final label = diff == 0
        ? 'اليوم'
        : diff == 1
            ? 'أمس'
            : DateFormat('d MMMM', 'ar').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
