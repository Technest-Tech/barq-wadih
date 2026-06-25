import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(dio: ref.watch(dioProvider));
});

// ── Firebase sign-in provider ─────────────────────────────────────────────────
// Ensures Firebase custom-token sign-in is complete before Firestore is used.

final firebaseChatAuthProvider = FutureProvider<void>((ref) async {
  await ref.read(chatRepositoryProvider).ensureFirebaseSignedIn();
});

// ── Conversations stream ──────────────────────────────────────────────────────

/// Real-time stream of all conversations for the current user, sorted by
/// latest message. [myUid] must be the Firebase UID (not the backend integer ID).
final conversationsStreamProvider =
    StreamProvider.family<List<ConversationModel>, String>((ref, myUid) {
      return ref.read(chatRepositoryProvider).conversationsStream(myUid);
    });

// ── Total unread count ────────────────────────────────────────────────────────

/// Derived provider — sums all unread counts across conversations.
/// [myId] is the backend integer ID string (used for unread map lookup).
///
/// This provider drives the global messages-tab badge, so it must work even
/// before the user opens the Messages screen. It therefore triggers Firebase
/// chat sign-in itself (by watching [firebaseChatAuthProvider]) and rebuilds
/// once sign-in completes, at which point the Firebase UID is available for
/// the Firestore conversations query.
final totalUnreadProvider = Provider.family<int, String>((ref, myId) {
  // Ensure Firebase is signed in; rebuild this provider when it completes.
  final authAsync = ref.watch(firebaseChatAuthProvider);
  if (!authAsync.hasValue) return 0;

  final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (myUid.isEmpty) return 0;

  final convAsync = ref.watch(conversationsStreamProvider(myUid));
  return convAsync.when(
    data: (conversations) =>
        conversations.fold(0, (sum, c) => sum + c.myUnreadCount(myId)),
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// ── Messages stream ───────────────────────────────────────────────────────────

/// Real-time stream of messages in a single conversation.
final messagesStreamProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
      return ref.read(chatRepositoryProvider).messagesStream(conversationId);
    });
