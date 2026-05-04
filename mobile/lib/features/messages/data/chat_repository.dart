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
  Future<void> ensureFirebaseSignedIn() async {
    if (FirebaseAuth.instance.currentUser != null) return;
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
    final existing = await convRef.get();
    if (existing.exists) return;

    final now = FieldValue.serverTimestamp();
    final unread = <String, int>{};
    for (final pid in participantIds) {
      unread[pid] = 0;
    }

    await convRef.set({
      'participantIds':       participantIds,
      'participantUids':      participantUids,
      'adId':                 adId,
      'adTitle':              adTitle,
      'adImage':              adImage,
      'peerNames':            peerNames,
      'peerAvatars':          peerAvatars,
      'lastMessage':          null,
      'lastMessageAt':        now,
      'lastMessageSenderId':  null,
      'unreadCount':          unread,
      'createdAt':            now,
      'updatedAt':            now,
    }, SetOptions(merge: true));
  }

  /// Create a conversation and post the buyer's opening message in one shot.
  /// Returns the conversation id. The notify call is best-effort.
  Future<String> startConversation({
    required int adId,
    required String myId,
    required String myUid,
    required String initialMessage,
  }) async {
    await ensureFirebaseSignedIn();
    final meta = await createConversation(adId);

    final conversationId  = meta['conversation_id'] as String;
    final participantIds  = List<String>.from(meta['participant_ids']  ?? []);
    final participantUids = List<String>.from(meta['participant_uids'] ?? []);
    final ad              = Map<String, dynamic>.from(meta['ad']     as Map);
    final seller          = Map<String, dynamic>.from(meta['seller'] as Map);
    final buyer           = Map<String, dynamic>.from(meta['buyer']  as Map);

    final sellerId = seller['id'].toString();
    final buyerId  = buyer['id'].toString();

    await _seedConversation(
      conversationId:  conversationId,
      participantIds:  participantIds,
      participantUids: participantUids,
      myId:            myId,
      adId:            ad['id'].toString(),
      adTitle:         ad['title'] as String? ?? '',
      adImage:         ad['image'] as String?,
      peerNames: {
        sellerId: seller['name'] as String? ?? '',
        buyerId:  buyer['name']  as String? ?? '',
      },
      peerAvatars: {
        sellerId: seller['avatar'] as String?,
        buyerId:  buyer['avatar']  as String?,
      },
    );

    await sendMessage(
      conversationId: conversationId,
      myId:           myId,
      myUid:          myUid,
      text:           initialMessage,
    );

    final sellerId = (seller['id'] as num?)?.toInt();
    if (sellerId != null) {
      notifyNewMessage(
        conversationId: conversationId,
        receiverId:     sellerId,
        messagePreview: initialMessage,
      );
    }

    return conversationId;
  }

  /// Real-time stream of all conversations for the current user.
  Stream<List<ConversationModel>> conversationsStream(String myId) {
    return _fs
        .collection('conversations')
        .where('participantIds', arrayContains: myId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ConversationModel.fromFirestore(d.id, d.data()))
            .toList());
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
        .map((snap) => snap.docs
            .map((d) => MessageModel.fromFirestore(d.id, d.data()))
            .toList());
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
    final otherId = participants.firstWhere((id) => id != myId, orElse: () => '');

    final now = FieldValue.serverTimestamp();

    // Write the message
    await convRef.collection('messages').add({
      'senderUid':  myUid,
      'senderId':   myId,
      'text':       text.trim(),
      'type':       'text',
      'imageUrl':   null,
      'isRead':     false,
      'readAt':     null,
      'createdAt':  now,
    });

    // Update conversation metadata
    final currentUnread =
        ((data['unreadCount'] as Map<dynamic, dynamic>?)?[otherId] as int?) ?? 0;

    await convRef.update({
      'lastMessage':         text.trim(),
      'lastMessageAt':       now,
      'lastMessageSenderId': myId,
      'unreadCount.$otherId': currentUnread + 1,
      'updatedAt':           now,
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
    final path = 'chat_images/$conversationId/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
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
    final otherId = participants.firstWhere((id) => id != myId, orElse: () => '');

    final now = FieldValue.serverTimestamp();
    final currentUnread =
        ((data['unreadCount'] as Map<dynamic, dynamic>?)?[otherId] as int?) ?? 0;

    await convRef.collection('messages').add({
      'senderUid':  myUid,
      'senderId':   myId,
      'text':       '📷 صورة',
      'type':       'image',
      'imageUrl':   downloadUrl,
      'isRead':     false,
      'readAt':     null,
      'createdAt':  now,
    });

    await convRef.update({
      'lastMessage':           '📷 صورة',
      'lastMessageAt':         now,
      'lastMessageSenderId':   myId,
      'unreadCount.$otherId':  currentUnread + 1,
      'updatedAt':             now,
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
        data: {
          'receiver_id':     receiverId,
          'message_preview': messagePreview,
        },
      );
    } catch (_) {
      // Non-fatal — push notifications are Sprint 10
    }
  }
}
