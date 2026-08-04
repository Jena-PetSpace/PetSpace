import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/services/notification_route_resolver.dart';

void main() {
  group('NotificationRouteResolver', () {
    test('social notification types resolve to their canonical routes', () {
      expect(
        NotificationRouteResolver.resolve(
          {'type': 'like', 'post_id': 'post-1'},
          currentUserId: 'me',
        ),
        '/post/post-1',
      );
      expect(
        NotificationRouteResolver.resolve(
          {'type': 'follow', 'sender_id': 'sender-1'},
          currentUserId: 'me',
        ),
        '/user-profile/sender-1?currentUserId=me',
      );
      for (final type in <String>['comment', 'mention']) {
        expect(
          NotificationRouteResolver.resolve(
            {'type': type, 'post_id': 'post-1'},
            currentUserId: 'me',
          ),
          '/post/post-1',
        );
      }
    });

    test('health and analysis routes do not depend on app receive state', () {
      expect(
        NotificationRouteResolver.resolve(
          {'type': 'health_alert'},
          currentUserId: 'me',
        ),
        '/health',
      );
      expect(
        NotificationRouteResolver.resolve(
          {'type': 'emotion_analysis'},
          currentUserId: 'me',
        ),
        '/ai-history-page',
      );
    });

    test('missing identifiers and unknown types fall back to the inbox', () {
      for (final data in <Map<String, dynamic>>[
        {'type': 'comment'},
        {'type': 'follow'},
        {'type': 'system'},
        {'type': 'admin_new_post'},
        {'type': 'unknown'},
        {},
      ]) {
        expect(
          NotificationRouteResolver.resolve(data, currentUserId: 'me'),
          '/notifications',
        );
      }
    });

    test('chat notifications open a room when a room id exists', () {
      expect(
        NotificationRouteResolver.resolve(
          {'type': 'chat', 'room_id': 'room-1'},
          currentUserId: 'me',
        ),
        '/chat/room-1',
      );
      expect(
        NotificationRouteResolver.resolve(
          {'type': 'chat'},
          currentUserId: 'me',
        ),
        '/chat',
      );
    });
  });
}
