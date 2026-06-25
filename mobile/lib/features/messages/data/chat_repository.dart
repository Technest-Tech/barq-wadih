import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dio/dio.dart';

import '../domain/chat_models.dart';

class ChatRepository {
  ChatRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;
  final _fs = FirebaseFirestore.instance;

  // ── Firebase custom token ────────────────────────────────────────────────────

  /// Mints a Firebase custom token via Laravel and signs into Firebase.
  /// Forces a token refresh when a session already exists so expired custom
  /// tokens (1-hour TTL) don't silently cause PERMISSION_DENIED on Firestore.
  ///
  /// Pass [expectedUid] (the backend MySQL user-id string) to detect stale or
  /// mismatched Firebase sessions (e.g. a leftover phone-OTP session whose UID
  /// isn't in participantUids). When the UIDs don't match the old session is
  /// signed out and a fresh custom token is minted.
  Future<void> ensureFirebaseSignedIn({String? expectedUid}) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      final uidMatches = expectedUid == null || current.uid == expectedUid;
      if (uidMatches) {
        try {
          await current.getIdToken(true); // throws if token can't be refreshed
          return;
        } catch (_) {
          // fall through to re-mint below
        }
      }
      // Wrong UID or stale token — sign out before re-minting.
      await FirebaseAuth.instance.signOut();
    }
    final res = await _dio.get('/chat/token');
    final token = res.data['data']['firebase_token'] as String;
    await FirebaseAuth.instance.signInWithCustomToken(token);
  }

  // ── Conversations ────────────────────────────────────────────────────────────

  /// Create or find an existing conversation for the given ad.
  /// Returns the seed metadata the client uses to (idempotently) create the
  /// Firestore conversation doc on first message.
  Future<Map<String, dynamic>> createConversation(int adId) async {
    final res = await _dio.post('/chat/conversations', data: {'ad_id': adId});
    return Map<String, dynamic>.from(res.data['data'] as Map);
  }

  /// Seed the conversation doc the first time a participant writes to it.
  /// Idempotent — on subsequent calls it merges in the latest metadata.
  ///
  /// Avoids a get() before set() because Firestore rules deny reads on
  /// non-existent documents (resource is null), which would prevent the
  /// initial document creation. Instead we set only the structural fields
  /// using mergeFields so existing message history is never overwritten.
  Future<void> _seedConversation({
    required String conversationId,
    required List<String> participantIds,
    required List<String> participantUids,
    required String myId,
    required String adId,
    required String adTitle,
    String? adImage,
    Map<String, String> peerNames = const {},
    Map<String, String?> peerAvatars = const {},
  }) async {
    final convRef = _fs.collection('conversations').doc(conversationId);
    await convRef.set(
      {
        'participantIds': participantIds,
        'participantUids': participantUids,
        'adId': adId,
        'adTitle': adTitle,
        'adImage': adImage,
        'peerNames': peerNames,
        'peerAvatars': peerAvatars,
      },
      SetOptions(
        mergeFields: [
          'participantIds',
          'participantUids',
          'adId',
          'adTitle',
          'adImage',
          'peerNames',
          'peerAvatars',
        ],
      ),
    );
  }

  /// Create a conversation and post the buyer's opening message in one shot.
  /// Returns the conversation id. The notify call is best-effort.
  Future<String> startConversation({
    required int adId,
    required String myId,
    required String initialMessage,
  }) async {
    // myId is both the Laravel user-id and the Firebase UID we minted with.
    // Pass it so ensureFirebaseSignedIn can detect stale/wrong sessions.
    await ensureFirebaseSignedIn(expectedUid: myId);
    // Derive the real Firebase UID *after* sign-in completes, not before.
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final meta = await createConversation(adId);

    final conversationId = meta['conversation_id'] as String;
    final participantIds = List<String>.from(meta['participant_ids'] ?? []);
    final participantUids = List<String>.from(meta['participant_uids'] ?? []);
    final ad = Map<String, dynamic>.from(meta['ad'] as Map);
    final seller = Map<String, dynamic>.from(meta['seller'] as Map);
    final buyer = Map<String, dynamic>.from(meta['buyer'] as Map);

    final sellerId = seller['id'].toString();
    final buyerId = buyer['id'].toString();
    final sellerIdInt = (seller['id'] as num?)?.toInt();

    await _seedConversation(
      conversationId: conversationId,
      participantIds: participantIds,
      participantUids: participantUids,
      myId: myId,
      adId: ad['id'].toString(),
      adTitle: ad['title'] as String? ?? '',
      adImage: ad['image'] as String?,
      peerNames: {
        sellerId: seller['name'] as String? ?? '',
        buyerId: buyer['name'] as String? ?? '',
      },
      peerAvatars: {
        sellerId: seller['avatar'] as String?,
        buyerId: buyer['avatar'] as String?,
      },
    );

    await sendMessage(
      conversationId: conversationId,
      myId: myId,
      myUid: myUid,
      text: initialMessage,
    );

    if (sellerIdInt != null) {
      notifyNewMessage(
        conversationId: conversationId,
        receiverId: sellerIdInt,
        messagePreview: initialMessage,
      );
    }

    return conversationId;
  }

  /// Real-time stream of all conversations for the current user.
  /// [myUid] must be the Firebase UID (not the backend integer ID).
  Stream<List<ConversationModel>> conversationsStream(String myUid) {
    return _fs
        .collection('conversations')
        .where('participantUids', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ConversationModel.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  // ── Messages ─────────────────────────────────────────────────────────────────

  /// Real-time stream of messages within a conversation.
  Stream<List<MessageModel>> messagesStream(String conversationId) {
    return _fs
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MessageModel.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  /// Send a plain text message.
  Future<void> sendMessage({
    required String conversationId,
    required String myId,
    required String myUid,
    required String text,
  }) async {
    final convRef = _fs.collection('conversations').doc(conversationId);
    final convSnap = await convRef.get();
    if (!convSnap.exists) return;

    final data = convSnap.data()!;
    final participants = List<String>.from(data['participantIds'] ?? []);
    final otherId = participants.firstWhere(
      (id) => id != myId,
      orElse: () => '',
    );

    final now = FieldValue.serverTimestamp();

    // Write the message
    await convRef.collection('messages').add({
      'senderUid': myUid,
      'senderId': myId,
      'text': text.trim(),
      'type': 'text',
      'imageUrl': null,
      'isRead': false,
      'readAt': null,
      'createdAt': now,
    });

    // Update conversation metadata
    final currentUnread =
        ((data['unreadCount'] as Map<dynamic, dynamic>?)?[otherId] as int?) ??
        0;

    await convRef.update({
      'lastMessage': text.trim(),
      'lastMessageAt': now,
      'lastMessageSenderId': myId,
      'unreadCount.$otherId': currentUnread + 1,
      'updatedAt': now,
    });
  }

  /// Upload voice recording to Firebase Storage then send as voice message.
  Future<void> sendVoice({
    required String conversationId,
    required String myId,
    required String myUid,
    required File voiceFile,
    required int duration,
    void Function(double progress)? onProgress,
  }) async {
    final path =
        'chat_voice/$conversationId/${DateTime.now().millisecondsSinceEpoch}.m4a';
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final task = storageRef.putFile(voiceFile);

    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }

    await task;
    final downloadUrl = await storageRef.getDownloadURL();

    final convRef = _fs.collection('conversations').doc(conversationId);
    final convSnap = await convRef.get();
    if (!convSnap.exists) return;

    final data = convSnap.data()!;
    final participants = List<String>.from(data['participantIds'] ?? []);
    final otherId = participants.firstWhere(
      (id) => id != myId,
      orElse: () => '',
    );

    final now = FieldValue.serverTimestamp();
    final currentUnread =
        ((data['unreadCount'] as Map<dynamic, dynamic>?)?[otherId] as int?) ??
        0;

    await convRef.collection('messages').add({
      'senderUid': myUid,
      'senderId': myId,
      'text': '🎤 رسالة صوتية',
      'type': 'voice',
      'imageUrl': null,
      'voiceUrl': downloadUrl,
      'duration': duration,
      'isRead': false,
      'readAt': null,
      'createdAt': now,
    });

    await convRef.update({
      'lastMessage': '🎤 رسالة صوتية',
      'lastMessageAt': now,
      'lastMessageSenderId': myId,
      'unreadCount.$otherId': currentUnread + 1,
      'updatedAt': now,
    });
  }

  /// Upload image to Firebase Storage then send as image message.
  Future<void> sendImage({
    required String conversationId,
    required String myId,
    required String myUid,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    final path =
        'chat_images/$conversationId/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
    final storageRef = FirebaseStorage.instance.ref().child(path);
    final task = storageRef.putFile(imageFile);

    if (onProgress != null) {
      task.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }

    await task;
    final downloadUrl = await storageRef.getDownloadURL();

    final convRef = _fs.collection('conversations').doc(conversationId);
    final convSnap = await convRef.get();
    if (!convSnap.exists) return;

    final data = convSnap.data()!;
    final participants = List<String>.from(data['participantIds'] ?? []);
    final otherId = participants.firstWhere(
      (id) => id != myId,
      orElse: () => '',
    );

    final now = FieldValue.serverTimestamp();
    final currentUnread =
        ((data['unreadCount'] as Map<dynamic, dynamic>?)?[otherId] as int?) ??
        0;

    await convRef.collection('messages').add({
      'senderUid': myUid,
      'senderId': myId,
      'text': '📷 صورة',
      'type': 'image',
      'imageUrl': downloadUrl,
      'isRead': false,
      'readAt': null,
      'createdAt': now,
    });

    await convRef.update({
      'lastMessage': '📷 صورة',
      'lastMessageAt': now,
      'lastMessageSenderId': myId,
      'unreadCount.$otherId': currentUnread + 1,
      'updatedAt': now,
    });
  }

  /// Mark all received messages as read and reset unread counter.
  Future<void> markAsRead({
    required String conversationId,
    required String myId,
  }) async {
    final convRef = _fs.collection('conversations').doc(conversationId);

    // Reset unread count
    await convRef.update({'unreadCount.$myId': 0});

    // Mark individual messages as read (only last batch for efficiency)
    final unreadSnap = await convRef
        .collection('messages')
        .where('senderId', isNotEqualTo: myId)
        .where('isRead', isEqualTo: false)
        .limit(50)
        .get();

    final batch = _fs.batch();
    for (final doc in unreadSnap.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    if (unreadSnap.docs.isNotEmpty) await batch.commit();
  }

  // ── Notification stub ────────────────────────────────────────────────────────

  Future<void> notifyNewMessage({
    required String conversationId,
    required int receiverId,
    required String messagePreview,
  }) async {
    try {
      await _dio.post(
        '/chat/conversations/$conversationId/notify',
        data: {'receiver_id': receiverId, 'message_preview': messagePreview},
      );
    } catch (_) {
      // Non-fatal — push notifications are Sprint 10
    }
  }
}
