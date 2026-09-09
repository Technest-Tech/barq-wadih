import 'package:barq_wadih/features/messages/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The web client seeds conversations with `participantNames`/
/// `participantAvatars`; this app seeds them with `peerNames`/`peerAvatars`.
/// Threads must resolve the peer either way, or one side shows the ad title
/// instead of the person's name.
void main() {
  const me = '11';
  const peer = '22';

  Map<String, dynamic> conversation(Map<String, dynamic> extra) => {
    'participantIds': [me, peer],
    'participantUids': [me, peer],
    'adId': '7',
    'adTitle': 'سيارة للبيع',
    'adImage': 'ads/7.jpg',
    'unreadCount': {me: 0, peer: 1},
    ...extra,
  };

  test('resolves a peer seeded by the mobile app', () {
    final c = ConversationModel.fromFirestore(
      'c1',
      conversation({
        'peerNames': {peer: 'سالم'},
        'peerAvatars': {peer: 'avatars/22.jpg'},
      }),
    );

    expect(c.otherName(me), 'سالم');
    expect(c.otherAvatar(me), 'avatars/22.jpg');
  });

  test('resolves a peer seeded by the web client', () {
    final c = ConversationModel.fromFirestore(
      'c2',
      conversation({
        'participantNames': {peer: 'سالم'},
        'participantAvatars': {peer: 'avatars/22.jpg'},
      }),
    );

    expect(c.otherName(me), 'سالم');
    expect(c.otherAvatar(me), 'avatars/22.jpg');
  });

  test('the mobile spelling wins when a doc carries both', () {
    final c = ConversationModel.fromFirestore(
      'c3',
      conversation({
        'participantNames': {peer: 'قديم'},
        'peerNames': {peer: 'محدث'},
      }),
    );

    expect(c.otherName(me), 'محدث');
  });

  test('falls back to the ad title and image when neither map is present', () {
    final c = ConversationModel.fromFirestore('c4', conversation({}));

    expect(c.otherName(me), 'سيارة للبيع');
    expect(c.otherAvatar(me), 'ads/7.jpg');
  });

  test('a null avatar falls back to the ad image rather than crashing', () {
    final c = ConversationModel.fromFirestore(
      'c5',
      conversation({
        'participantNames': {peer: 'سالم'},
        'participantAvatars': {peer: null},
      }),
    );

    expect(c.otherName(me), 'سالم');
    expect(c.otherAvatar(me), 'ads/7.jpg');
  });
}
