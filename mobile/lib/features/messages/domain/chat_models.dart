// Chat domain models — maps to Firestore document structure.

/// Flattens the web (`participantNames`) and mobile (`peerNames`) spellings of
/// the same map into one lookup. Later sources win on key collisions.
Map<String, String> mergeStringMap(dynamic first, dynamic second) {
  final out = <String, String>{};
  for (final source in [first, second]) {
    if (source is Map) {
      source.forEach((k, v) {
        if (v != null) out[k.toString()] = v.toString();
      });
    }
  }
  return out;
}

/// Same as [mergeStringMap] but keeps explicit nulls (missing avatars).
Map<String, String?> mergeNullableStringMap(dynamic first, dynamic second) {
  final out = <String, String?>{};
  for (final source in [first, second]) {
    if (source is Map) {
      source.forEach((k, v) => out[k.toString()] = v?.toString());
    }
  }
  return out;
}

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final List<String> participantUids;
  final String adId;
  final String adTitle;
  final String? adImage;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final Map<String, String> peerNames;
  final Map<String, String?> peerAvatars;

  const ConversationModel({
    required this.id,
    required this.participantIds,
    required this.participantUids,
    required this.adId,
    required this.adTitle,
    this.adImage,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    required this.unreadCount,
    required this.createdAt,
    this.peerNames = const {},
    this.peerAvatars = const {},
  });

  int myUnreadCount(String myId) => unreadCount[myId] ?? 0;

  String otherId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => '');

  /// Returns the display name for the other participant.
  String otherName(String myId) {
    return peerNames[otherId(myId)] ?? adTitle;
  }

  /// Returns the avatar URL for the other participant (falls back to ad image).
  String? otherAvatar(String myId) {
    return peerAvatars[otherId(myId)] ?? adImage;
  }

  factory ConversationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? toDateTime(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return ConversationModel(
      id: id,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantUids: List<String>.from(data['participantUids'] ?? []),
      adId: data['adId']?.toString() ?? '',
      adTitle: data['adTitle']?.toString() ?? '',
      adImage: data['adImage']?.toString(),
      lastMessage: data['lastMessage']?.toString(),
      lastMessageAt: toDateTime(data['lastMessageAt']),
      lastMessageSenderId: data['lastMessageSenderId']?.toString(),
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map<dynamic, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      ),
      createdAt: toDateTime(data['createdAt']) ?? DateTime.now(),
      // Threads created by the web client carry `participantNames`/
      // `participantAvatars` instead of `peerNames`/`peerAvatars`. Merge both
      // so either schema resolves the peer's name and avatar.
      peerNames: mergeStringMap(data['participantNames'], data['peerNames']),
      peerAvatars: mergeNullableStringMap(
        data['participantAvatars'],
        data['peerAvatars'],
      ),
    );
  }
}

class MessageModel {
  final String id;
  final String senderUid;
  final String senderId;
  final String text;
  final String type; // 'text' | 'image' | 'voice'
  final String? imageUrl;
  final String? voiceUrl;
  final int? duration; // voice duration in seconds
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderUid,
    required this.senderId,
    required this.text,
    required this.type,
    this.imageUrl,
    this.voiceUrl,
    this.duration,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  bool get isImage => type == 'image';
  bool get isVoice => type == 'voice';

  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? toDateTime(dynamic v) {
      if (v == null) return null;
      try {
        return (v as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return MessageModel(
      id: id,
      senderUid: data['senderUid']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      type: data['type']?.toString() ?? 'text',
      imageUrl: data['imageUrl']?.toString(),
      voiceUrl: data['voiceUrl']?.toString(),
      duration: (data['duration'] as num?)?.toInt(),
      isRead: data['isRead'] == true,
      readAt: toDateTime(data['readAt']),
      createdAt: toDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }
}
