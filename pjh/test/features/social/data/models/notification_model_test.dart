import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/data/models/notification_model.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/notification.dart';

void main() {
  group('NotificationModel.fromSupabaseJson', () {
    test('parses canonical columns and prefers joined sender profile', () {
      final model = NotificationModel.fromSupabaseJson(<String, dynamic>{
        'id': 'notification-1',
        'user_id': 'receiver-1',
        'sender_id': 'sender-1',
        'type': 'admin_new_post',
        'title': '새 글',
        'body': '새 글이 등록됐어요.',
        'read': true,
        'created_at': '2026-07-18T00:00:00Z',
        'post_id': 'post-1',
        'comment_id': null,
        'data': <String, dynamic>{
          'sender_name': 'Fallback name',
          'route': '/post/post-1',
        },
        'sender': <String, dynamic>{
          'display_name': 'Joined name',
          'photo_url': 'https://example.com/profile.jpg',
        },
      });

      expect(model.id, 'notification-1');
      expect(model.userId, 'receiver-1');
      expect(model.senderId, 'sender-1');
      expect(model.senderName, 'Joined name');
      expect(model.senderProfileImage, 'https://example.com/profile.jpg');
      expect(model.type, NotificationType.adminNewPost);
      expect(model.isRead, isTrue);
      expect(model.postId, 'post-1');
      expect(model.data['route'], '/post/post-1');
    });

    test('uses data sender snapshot only when joined user is unavailable', () {
      final model = NotificationModel.fromSupabaseJson(<String, dynamic>{
        'id': 'notification-2',
        'user_id': 'receiver-1',
        'sender_id': null,
        'type': 'follow',
        'title': '새 팔로워',
        'body': '팔로우를 시작했어요.',
        'read': false,
        'created_at': '2026-07-18T01:00:00Z',
        'data': <String, dynamic>{
          'sender_id': 'deleted-sender',
          'sender_name': '탈퇴한 사용자',
        },
        'sender': null,
      });

      expect(model.senderId, 'deleted-sender');
      expect(model.senderName, '탈퇴한 사용자');
      expect(model.senderProfileImage, isNull);
    });

    test('unknown and legacy camelCase types never become like', () {
      final unknown = NotificationModel.fromSupabaseJson(<String, dynamic>{
        'type': 'unsupported_type',
        'created_at': '2026-07-18T02:00:00Z',
      });
      final legacy = NotificationModel.fromSupabaseJson(<String, dynamic>{
        'type': 'emotionAnalysis',
        'created_at': '2026-07-18T02:00:00Z',
      });

      expect(unknown.type, NotificationType.unknown);
      expect(legacy.type, NotificationType.unknown);
      expect(unknown.type, isNot(NotificationType.like));
    });
  });

  test('notification type wire names are canonical snake_case', () {
    const expected = <NotificationType, String>{
      NotificationType.like: 'like',
      NotificationType.comment: 'comment',
      NotificationType.follow: 'follow',
      NotificationType.mention: 'mention',
      NotificationType.system: 'system',
      NotificationType.adminNewPost: 'admin_new_post',
      NotificationType.emotionAnalysis: 'emotion_analysis',
      NotificationType.healthAlert: 'health_alert',
      NotificationType.friendRequest: 'friend_request',
      NotificationType.postShare: 'post_share',
      NotificationType.unknown: 'unknown',
    };

    for (final entry in expected.entries) {
      expect(entry.key.wireName, entry.value);
      if (entry.key != NotificationType.unknown) {
        expect(NotificationTypeContract.fromWireName(entry.value), entry.key);
      }
    }
  });
}
