import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/data/notification_providers.dart';
import '../../../safety/presentation/user_safety_sheet.dart';
import '../../data/chat_providers.dart';
import '../../domain/chat_models.dart';
import '../widgets/chat_background.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/image_cache_manager.dart';
import '../../../../core/services/image_upload_preprocessor.dart';

const _kHeaderBlue = Color(0xFF1B4FE4);
const _kBubbleSent = Color(0xFFDCF8C6); // WhatsApp green
const _kBubbleRecv = Colors.white;
const _kInputBg = Color(0xFFF0F2F5);
const _kTextPrimary = Color(0xFF0A1628);
const _kTickRead = Color(0xFF1B4FE4);

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
  bool _convMetaLoading = false;
  bool _firestoreInitialised = false;
  bool _markingRead = false;

  // ── Upload progress ─────────────────────────────────────────────────────────
  // Label is non-null exactly while an upload banner should be on screen.
  // Progress is null when the transfer is finished but the Firestore write is
  // still in flight, which renders as an indeterminate bar.
  String? _uploadLabel;
  double? _uploadProgress;

  // ── Voice recording state ────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // ── Recorded-but-not-yet-sent clip ──────────────────────────────────────────
  // Stopping the recorder parks the clip here instead of firing it off, so the
  // user gets an explicit send button and a chance to hear it back first.
  String? _pendingVoicePath;
  int _pendingVoiceSeconds = 0;
  bool _isPreviewPlaying = false;

  // ── Voice playback state ─────────────────────────────────────────────────────
  final _player = AudioPlayer();
  String? _playingMsgId;
  bool _isPlayerPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingMsgId = null;
          _isPlayerPlaying = false;
          _isPreviewPlaying = false;
        });
      }
    });
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      final playing = state == PlayerState.playing;
      setState(() {
        _isPlayerPlaying = playing;
        // The same player drives message playback and clip preview; only one
        // of them can be active, so mirror the flag onto whichever is showing.
        if (_pendingVoicePath != null && _playingMsgId == null) {
          _isPreviewPlaying = playing;
        }
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  /// Fetch the conversation doc once.
  ///
  /// Deliberately a get() rather than a snapshots() listener: the security
  /// rules gate reads on `resource.data.participantUids`, which is null for a
  /// document that does not exist yet, so a listener attached before the first
  /// message would be permission-denied and Firestore does not retry a denied
  /// listener. A freshly opened chat seeds its doc on first send instead, and
  /// [_refreshConvMetaIfMissing] picks it up from the messages stream.
  Future<void> _loadConvMeta() async {
    if (_convMetaLoading) return;
    _convMetaLoading = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .get();
      if (mounted && snap.exists) {
        setState(() => _convMeta = snap.data());
      }
    } catch (_) {
      /* swallow */
    } finally {
      _convMetaLoading = false;
    }
  }

  void _refreshConvMetaIfMissing() {
    if (_convMeta == null) _loadConvMeta();
  }

  Future<void> _markRead() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .markAsRead(
            conversationId: widget.conversationId,
            myId: user.id.toString(),
          );
    } catch (e) {
      // Read receipts must never prevent the conversation itself from loading.
      debugPrint('ConversationScreen: markAsRead failed — $e');
    }

    // Firestore only tracks the chat's own unread counter. The bell badge is
    // driven by the backend notification table, which knows nothing about
    // this — so without the call below, reading the message here left its
    // "رسالة جديدة" notification unread forever.
    await clearNotificationsFor(
      ref,
      type: 'new_message',
      conversationId: widget.conversationId,
    );
  }

  /// Clear read state for messages that arrive while the chat is on screen.
  ///
  /// Guarded twice over: only when the peer actually has an unread message
  /// waiting, and never concurrently — the stream ticks on every write,
  /// including our own.
  void _markIncomingRead(List<MessageModel>? messages, String myId) {
    if (_markingRead || messages == null) return;
    final hasUnreadFromPeer = messages.any(
      (m) => m.senderId != myId && !m.isRead,
    );
    if (!hasUnreadFromPeer) return;
    _markingRead = true;
    unawaited(_markRead().whenComplete(() => _markingRead = false));
  }

  void _initialiseFirestoreAfterAuth() {
    if (_firestoreInitialised) return;
    _firestoreInitialised = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadConvMeta();
      await _markRead();
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _textController.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            conversationId: widget.conversationId,
            myId: user.id.toString(),
            myUid: _firebaseUid(),
            text: text,
          );
      _scrollToBottom();
    } on ApiException catch (e) {
      _textController.text = text;
      _showError(e.message);
    } catch (_) {
      _textController.text = text;
      _showError('تعذر إرسال الرسالة. حاول مرة أخرى.');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _beginUpload('جارٍ إرسال الصورة…');
    try {
      final prepared = await ImageUploadPreprocessor.prepare(picked);
      await ref
          .read(chatRepositoryProvider)
          .sendImage(
            conversationId: widget.conversationId,
            myId: user.id.toString(),
            myUid: _firebaseUid(),
            imageFile: File(prepared.path),
            onProgress: _onUploadProgress,
          );
      _scrollToBottom();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('تعذر إرسال الصورة. حاول مرة أخرى.');
    } finally {
      _endUpload();
    }
  }

  // ── Upload progress plumbing ─────────────────────────────────────────────────

  void _beginUpload(String label) {
    setState(() {
      _uploading = true;
      _uploadLabel = label;
      _uploadProgress = 0;
    });
  }

  void _onUploadProgress(double progress) {
    if (!mounted) return;
    // At 100% the bytes are up but the Firestore write still has to land, so
    // drop to indeterminate rather than parking a full bar on screen.
    setState(() => _uploadProgress = progress >= 1 ? null : progress);
  }

  void _endUpload() {
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _uploadLabel = null;
      _uploadProgress = null;
    });
  }

  // ── Voice recording ──────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      // Returning silently made the record button look broken once the user
      // had declined the microphone prompt. Say what happened instead.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لإرسال رسالة صوتية، فعّل إذن الميكروفون من إعدادات جهازك.',
            ),
          ),
        );
      }
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final filePath =
        '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
  }

  /// Stop the recorder and hold the clip for review. Sending is a separate,
  /// deliberate tap — see [_sendPendingVoice].
  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordingDuration.inSeconds;

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    if (path == null || duration == 0) {
      if (path != null) await _deleteFile(path);
      return;
    }

    setState(() {
      _pendingVoicePath = path;
      _pendingVoiceSeconds = duration;
      _isPreviewPlaying = false;
    });
  }

  Future<void> _sendPendingVoice() async {
    final path = _pendingVoicePath;
    if (path == null) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await _player.stop();
    if (mounted) setState(() => _isPreviewPlaying = false);

    _beginUpload('جارٍ إرسال الرسالة الصوتية…');
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendVoice(
            conversationId: widget.conversationId,
            myId: user.id.toString(),
            myUid: _firebaseUid(),
            voiceFile: File(path),
            duration: _pendingVoiceSeconds,
            onProgress: _onUploadProgress,
          );
      await _deleteFile(path);
      if (mounted) {
        setState(() {
          _pendingVoicePath = null;
          _pendingVoiceSeconds = 0;
        });
      }
      _scrollToBottom();
    } on ApiException catch (e) {
      // Keep the clip so the send can be retried without re-recording.
      _showError(e.message);
    } catch (_) {
      _showError('تعذر إرسال التسجيل. حاول مرة أخرى.');
    } finally {
      _endUpload();
    }
  }

  Future<void> _discardPendingVoice() async {
    final path = _pendingVoicePath;
    await _player.stop();
    if (mounted) {
      setState(() {
        _pendingVoicePath = null;
        _pendingVoiceSeconds = 0;
        _isPreviewPlaying = false;
      });
    }
    if (path != null) await _deleteFile(path);
  }

  Future<void> _togglePreviewPlay() async {
    final path = _pendingVoicePath;
    if (path == null) return;

    if (_isPreviewPlaying) {
      await _player.pause();
      return;
    }
    // Hand the player over from any message bubble that was playing.
    await _player.stop();
    if (mounted) setState(() => _playingMsgId = null);
    await _player.play(DeviceFileSource(path));
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });
    }
    if (path != null) await _deleteFile(path);
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      /* a stray temp file is harmless */
    }
  }

  String _formatSeconds(int secs) =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:'
      '${(secs % 60).toString().padLeft(2, '0')}';

  // ── Voice playback ───────────────────────────────────────────────────────────

  Future<void> _togglePlay(MessageModel msg) async {
    if (msg.voiceUrl == null) return;

    if (_playingMsgId == msg.id && _isPlayerPlaying) {
      await _player.pause();
      return;
    }

    if (_playingMsgId == msg.id && !_isPlayerPlaying) {
      await _player.resume();
      return;
    }

    // Different message — stop current and start new
    await _player.stop();
    setState(() => _playingMsgId = msg.id);
    await _player.play(UrlSource(msg.voiceUrl!));
  }

  String _firebaseUid() {
    return FirebaseAuth.instance.currentUser?.uid ??
        'user_${ref.read(currentUserProvider)?.id ?? 0}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _openSafetyControls({
    required String otherId,
    required String displayName,
  }) async {
    final userId = int.tryParse(otherId);
    if (userId == null) {
      _showError('تعذر تحديد المستخدم');
      return;
    }

    final blocked = await showUserSafetySheet(
      context,
      userId: userId,
      userName: displayName,
      conversationId: widget.conversationId,
    );
    if (blocked == true && mounted) {
      Navigator.of(context).maybePop();
    }
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

    // A notification can deep-link here while the app is still restoring the
    // backend session. Do not start Firebase auth with an empty/wrong UID.
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFECE5DD),
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final firebaseAuth = ref.watch(firebaseChatAuthProvider(myId));
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
              Text(
                'تعذّر تحميل الرسائل',
                style: TextStyle(color: Colors.grey[700], fontSize: 15),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  _firestoreInitialised = false;
                  ref.invalidate(firebaseChatAuthProvider(myId));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    _initialiseFirestoreAfterAuth();

    final msgsAsync = ref.watch(messagesStreamProvider(widget.conversationId));

    ref.listen(messagesStreamProvider(widget.conversationId), (_, next) {
      _scrollToBottom();
      // A chat opened before its first message has no Firestore doc yet, so the
      // initial metadata fetch came back empty. Sending seeds it — retry here
      // so the ad header and peer name appear without leaving the screen.
      _refreshConvMetaIfMissing();
      // A message that lands while the chat is already open is read on arrival
      // — it must not leave an unread notification (or badge) behind it.
      _markIncomingRead(next.value, myId);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: _buildAppBar(),
      body: ChatBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildAdHeader(),
              Expanded(
                child: msgsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('خطأ: $e')),
                  data: (messages) => _buildMessageList(messages, myId),
                ),
              ),
              _buildUploadBanner(),
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                ),
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
        final msg = messages[index];
        final isMe = msg.senderId == myId;
        final showSep =
            index == 0 ||
            !_sameDay(messages[index - 1].createdAt, msg.createdAt);

        return Column(
          children: [
            if (showSep) _DateSeparator(date: msg.createdAt),
            _MessageBubble(
              msg: msg,
              isMe: isMe,
              isPlaying: _playingMsgId == msg.id && _isPlayerPlaying,
              onPlayTap: msg.isVoice ? () => _togglePlay(msg) : null,
            ),
          ],
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final myId = ref.read(currentUserProvider)?.id.toString() ?? '';
    final participantIds = List<String>.from(
      (_convMeta?['participantIds'] as List<dynamic>?) ?? [],
    );
    final otherId = participantIds.firstWhere(
      (id) => id != myId,
      orElse: () => '',
    );

    final peerNames = mergeStringMap(
      _convMeta?['participantNames'],
      _convMeta?['peerNames'],
    );
    final peerAvatars = mergeNullableStringMap(
      _convMeta?['participantAvatars'],
      _convMeta?['peerAvatars'],
    );

    final displayName =
        peerNames[otherId] ?? (_convMeta?['adTitle'] as String?) ?? 'المحادثة';
    final avatarUrl =
        peerAvatars[otherId] ?? (_convMeta?['adImage'] as String?);
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();

    return AppBar(
      backgroundColor: _kHeaderBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: BackButton(
        color: Colors.white,
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.messages);
          }
        },
      ),
      titleSpacing: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Row(
        children: [
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
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    cacheManager: AppImageCacheManager.instance,
                    fit: BoxFit.cover,
                    memCacheWidth: 120,
                    memCacheHeight: 120,
                    errorWidget: (_, __, ___) => Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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
          onPressed: otherId.isEmpty
              ? null
              : () => _openSafetyControls(
                  otherId: otherId,
                  displayName: displayName,
                ),
          tooltip: 'المزيد',
        ),
      ],
    );
  }

  /// Pinned strip under the app bar naming the ad this thread is about, so the
  /// subject stays visible no matter how far back the user scrolls. Mirrors the
  /// web client's ad card. Renders nothing until the Firestore metadata lands.
  Widget _buildAdHeader() {
    final adId = int.tryParse(_convMeta?['adId']?.toString() ?? '');
    if (adId == null) return const SizedBox.shrink();

    final title = (_convMeta?['adTitle'] as String?)?.trim();
    final image = (_convMeta?['adImage'] as String?)?.trim();
    final hasImage = image != null && image.startsWith('http');

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => context.push(AppRoutes.adDetailPath(adId)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x1F1B4FE4), width: 1),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: image,
                          cacheManager: AppImageCacheManager.instance,
                          fit: BoxFit.cover,
                          memCacheWidth: 160,
                          memCacheHeight: 160,
                          errorWidget: (_, __, ___) => const _AdThumbFallback(),
                        )
                      : const _AdThumbFallback(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'المحادثة بخصوص',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title == null || title.isEmpty ? 'الإعلان' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'عرض الإعلان',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kHeaderBlue,
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: _kHeaderBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Progress strip shown above the composer while media is uploading. The
  /// composer's own icon spinner is easy to miss, which made image sends look
  /// like nothing had happened.
  Widget _buildUploadBanner() {
    final label = _uploadLabel;
    if (label == null) return const SizedBox.shrink();

    final pct = _uploadProgress;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, value: pct),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: const Color(0x141B4FE4),
                  ),
                ),
              ],
            ),
          ),
          if (pct != null) ...[
            const SizedBox(width: 10),
            Text(
              '${(pct * 100).round()}%',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    // ── Recording state UI ───────────────────────────────────────────────────
    if (_isRecording) {
      final label = _formatSeconds(_recordingDuration.inSeconds);
      return Container(
        color: _kInputBg,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            // Cancel
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              onPressed: _cancelRecording,
              tooltip: 'إلغاء',
            ),
            // Animated pulse dot
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            // Timer
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
            const Spacer(),
            // There is no swipe gesture wired up, so the old "swipe to cancel"
            // hint pointed at nothing. Name the two buttons that do exist.
            Text(
              'أوقف التسجيل للمراجعة',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(width: 8),
            // Stop — hands off to the review bar, which is where sending happens.
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stop_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Recorded clip awaiting an explicit send ──────────────────────────────
    if (_pendingVoicePath != null) {
      return Container(
        color: _kInputBg,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              onPressed: _uploading ? null : _discardPendingVoice,
              tooltip: 'حذف التسجيل',
            ),
            // Preview playback
            GestureDetector(
              onTap: _uploading ? null : _togglePreviewPlay,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPreviewPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: _kHeaderBlue,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatSeconds(_pendingVoiceSeconds),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
            const Spacer(),
            // Unmistakable send affordance — the previous flow sent the clip
            // the instant recording stopped, with only a stop icon to go on.
            GestureDetector(
              onTap: _uploading ? null : _sendPendingVoice,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _uploading ? Colors.grey : _kHeaderBlue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _uploading
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x441B4FE4),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'إرسال',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Normal input UI ──────────────────────────────────────────────────────
    return Container(
      color: _kInputBg,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mic / Send FAB on leading edge
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
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                );
              }
              return GestureDetector(
                onTap: _uploading ? null : _startRecording,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _uploading ? Colors.grey : _kHeaderBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Pill-shaped input with camera + attach
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
                  IconButton(
                    icon: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.grey[600],
                          ),
                    onPressed: _uploading ? null : _pickImage,
                    splashRadius: 22,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: Colors.grey[600],
                    ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
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

class _AdThumbFallback extends StatelessWidget {
  const _AdThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x141B4FE4),
      child: const Icon(
        Icons.shopping_bag_outlined,
        size: 20,
        color: _kHeaderBlue,
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.msg,
    required this.isMe,
    this.isPlaying = false,
    this.onPlayTap,
  });

  final MessageModel msg;
  final bool isMe;
  final bool isPlaying;
  final VoidCallback? onPlayTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(msg.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe ? _kBubbleSent : _kBubbleRecv,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe
                ? const Radius.circular(12)
                : const Radius.circular(2),
            bottomRight: isMe
                ? const Radius.circular(2)
                : const Radius.circular(12),
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
                  child: CachedNetworkImage(
                    imageUrl: msg.imageUrl!,
                    cacheManager: AppImageCacheManager.instance,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                    memCacheWidth: 660,
                    memCacheHeight: 660,
                    placeholder: (_, __) => const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(
                      width: 220,
                      height: 220,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              else if (msg.isVoice)
                _VoiceContent(
                  duration: msg.duration ?? 0,
                  isPlaying: isPlaying,
                  onPlayTap: onPlayTap,
                  isMe: isMe,
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

              // Meta row: time + read receipt
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
                        msg.isRead
                            ? Icons.done_all_rounded
                            : Icons.check_rounded,
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

// ── Voice message content ──────────────────────────────────────────────────────

class _VoiceContent extends StatelessWidget {
  const _VoiceContent({
    required this.duration,
    required this.isPlaying,
    required this.isMe,
    this.onPlayTap,
  });

  final int duration;
  final bool isPlaying;
  final bool isMe;
  final VoidCallback? onPlayTap;

  String get _durationLabel {
    final m = (duration ~/ 60).toString().padLeft(2, '0');
    final s = (duration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = isMe ? const Color(0xFF075E54) : _kHeaderBlue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play / Pause button
        GestureDetector(
          onTap: onPlayTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Waveform bars (decorative)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(18, (i) {
                  final heights = [
                    6.0,
                    10.0,
                    14.0,
                    8.0,
                    12.0,
                    16.0,
                    6.0,
                    10.0,
                    14.0,
                    8.0,
                    12.0,
                    16.0,
                    6.0,
                    10.0,
                    14.0,
                    8.0,
                    12.0,
                    6.0,
                  ];
                  return Expanded(
                    child: Container(
                      height: heights[i],
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? accentColor
                            : accentColor.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                _durationLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Date separator ─────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
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
