import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/chat_providers.dart';
import '../../domain/chat_models.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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

    final user    = ref.read(currentUserProvider);
    final fireUid = _firebaseUid();
    if (user == null) return;

    _textController.clear();

    await ref.read(chatRepositoryProvider).sendMessage(
      conversationId: widget.conversationId,
      myId:           user.id.toString(),
      myUid:          fireUid,
      text:           text,
    );

    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    final user    = ref.read(currentUserProvider);
    final fireUid = _firebaseUid();
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      await ref.read(chatRepositoryProvider).sendImage(
        conversationId: widget.conversationId,
        myId:           user.id.toString(),
        myUid:          fireUid,
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
    final user    = ref.watch(currentUserProvider);
    final myId    = user?.id.toString() ?? '';
    final msgsAsync = ref.watch(messagesStreamProvider(widget.conversationId));

    // Auto-scroll on new messages
    ref.listen(messagesStreamProvider(widget.conversationId), (_, __) {
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: msgsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('ابدأ المحادثة!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                        const SizedBox(height: 4),
                        Text('لا توجد رسائل بعد',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg  = messages[index];
                    final isMe = msg.senderId == myId;

                    // Date separator
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
              },
            ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A1628),
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'المحادثة',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
      ),
      // Future: show ad title and thumbnail from conversation metadata
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // Image button
            IconButton(
              icon: _uploading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              onPressed: _uploading ? null : _pickImage,
              color: Colors.grey[600],
            ),

            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textAlign: TextAlign.right,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'اكتب رسالتك...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (_, value, __) {
                final enabled = value.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: enabled ? _send : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: enabled
                          ? const Color(0xFF1B4FE4)
                          : Colors.grey[300],
                      boxShadow: enabled
                          ? [const BoxShadow(color: Color(0x441B4FE4), blurRadius: 8, offset: Offset(0, 3))]
                          : [],
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: enabled ? Colors.white : Colors.grey[500],
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1B4FE4) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(4) : const Radius.circular(18),
            bottomRight: isMe ? const Radius.circular(18) : const Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMe ? 0.15 : 0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.isImage && msg.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    msg.imageUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            width: 200, height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
                )
              else
                Text(
                  msg.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF0A1628),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white54 : Colors.grey[500],
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
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }
}
