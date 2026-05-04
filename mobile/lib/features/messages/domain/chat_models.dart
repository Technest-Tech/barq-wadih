// Chat domain models — maps to Firestore document structure.

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

  /// Returns the display name for the other participant.
  String otherName(String myId) {
    final otherId = participantIds.firstWhere((id) => id != myId, orElse: () => '');
    return peerNames[otherId] ?? adTitle;
  }

  /// Returns the avatar URL for the other participant (falls back to ad image).
  String? otherAvatar(String myId) {
    final otherId = participantIds.firstWhere((id) => id != myId, orElse: () => '');
    return peerAvatars[otherId] ?? adImage;
  }

  factory ConversationModel.fromFirestore(String id, Map<String, dynamic> data) {
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
      id:                    id,
      participantIds:        List<String>.from(data['participantIds'] ?? []),
      participantUids:       List<String>.from(data['participantUids'] ?? []),
      adId:                  data['adId']?.toString() ?? '',
      adTitle:               data['adTitle']?.toString() ?? '',
      adImage:               data['adImage']?.toString(),
      lastMessage:           data['lastMessage']?.toString(),
      lastMessageAt:         toDateTime(data['lastMessageAt']),
      lastMessageSenderId:   data['lastMessageSenderId']?.toString(),
      unreadCount:           Map<String, int>.from(
        (data['unreadCount'] as Map<dynamic, dynamic>? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      ),
      createdAt:             toDateTime(data['createdAt']) ?? DateTime.now(),
      peerNames:             Map<String, String>.from(
        (data['peerNames'] as Map<dynamic, dynamic>? ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      ),
      peerAvatars:           Map<String, String?>.from(
        (data['peerAvatars'] as Map<dynamic, dynamic>? ?? {})
            .map((k, v) => MapEntry(k.toString(), v?.toString())),
      ),
    );
  }
}

class MessageModel {
  final String id;
  final String senderUid;
  final String senderId;
  final String text;
  final String type; // 'text' | 'image'
  final String? imageUrl;
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
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  bool get isImage => type == 'image';

  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? toDateTime(dynamic v) {
      if (v == null) return null;
      try { return (v as dynamic).toDate() as DateTime; } catch (_) { return null; }
    }

    return MessageModel(
      id:        id,
      senderUid: data['senderUid']?.toString() ?? '',
      senderId:  data['senderId']?.toString() ?? '',
      text:      data['text']?.toString() ?? '',
      type:      data['type']?.toString() ?? 'text',
      imageUrl:  data['imageUrl']?.toString(),
      isRead:    data['isRead'] == true,
      readAt:    toDateTime(data['readAt']),
      createdAt: toDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }
}
