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
  /// Returns the Firestore conversation ID.
  Future<String> createConversation(int adId) async {
    final res = await _dio.post('/chat/conversations', data: {'ad_id': adId});
    return res.data['data']['conversation_id'] as String;
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
