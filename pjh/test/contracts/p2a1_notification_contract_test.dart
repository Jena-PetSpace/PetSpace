import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

void main() {
  group('P2A-1 source contract', () {
    test('app has one token lifecycle owner and no legacy push producer', () {
      final appSource = _dartFiles(
        'lib',
      ).map((file) => file.readAsStringSync()).join('\n');
      final fcmService = _read('lib/core/services/fcm_service.dart');
      final notificationService = _read(
        'lib/core/services/notification_service.dart',
      );

      expect(appSource, isNot(contains('PushNotificationService')));
      expect(fcmService, isNot(contains('onTokenRefresh')));
      expect(notificationService, contains('onTokenRefresh'));
      expect(appSource, isNot(contains('FCM Token:')));
      expect(appSource, isNot(contains(r'fcm_token=$')));
    });

    test('Supabase notification reads use canonical read and sender join', () {
      final source = _read(
        'lib/features/social/data/datasources/'
        'social_remote_data_source_impl_notification.dart',
      );

      expect(source, contains('notifications_sender_id_fkey'));
      expect(source, contains(".eq('read', false)"));
      expect(source, contains("{'read': true}"));
      expect(source, isNot(contains('is_read')));
      expect(source, isNot(contains(".from('notifications').insert")));
    });

    test('Edge functions separate row creation from push delivery', () {
      final createEdge = _read(
        '../supabase/functions/send-notification/index.ts',
      );
      final pushEdge = _read(
        '../supabase/functions/send-push-notification/index.ts',
      );

      expect(createEdge, contains('"create_notification"'));
      expect(createEdge, contains('p_event_key'));
      expect(createEdge, contains(r'Bearer ${serviceRoleKey}'));
      expect(createEdge, isNot(contains('fcm.googleapis.com')));
      expect(createEdge, isNot(contains('.from("notifications").insert')));

      expect(pushEdge, contains('notification_id'));
      expect(pushEdge, contains(r'Bearer ${serviceRoleKey}'));
      expect(pushEdge, contains('"enabled_push"'));
      expect(pushEdge, contains(".eq(\"is_active\", true)"));
      expect(pushEdge, contains('is_sent: true'));
      expect(pushEdge, contains('sent_at:'));
      expect(pushEdge, contains('channel_id: androidChannelId'));
      expect(
        pushEdge.indexOf('result.notification_id = notification.id'),
        greaterThan(pushEdge.indexOf('Object.entries(notification.data')),
      );
      expect(pushEdge, contains('case "health_alert"'));
      for (final channelId in <String>['social', 'health', 'chat', 'system']) {
        expect(pushEdge, contains('return "$channelId"'));
      }
      expect(pushEdge, isNot(contains('console.log(device.fcm_token')));
    });

    test('remote and local notification taps share one route resolver', () {
      final fcmService = _read('lib/core/services/fcm_service.dart');
      final localService = _read(
        'lib/core/services/local_notification_service.dart',
      );
      final router = _read('lib/core/navigation/app_router.dart');
      final manifest = _read('android/app/src/main/AndroidManifest.xml');

      expect(fcmService, contains('NotificationRouteResolver.resolve'));
      expect(localService, contains('NotificationRouteResolver.resolve'));
      expect(localService, contains('getNotificationAppLaunchDetails'));
      for (final channelId in <String>['social', 'health', 'chat', 'system']) {
        expect(localService, contains("'$channelId'"));
      }
      expect(
        router,
        contains('sl<LocalNotificationService>().navigatorKey = navigatorKey'),
      );
      expect(
        manifest,
        contains('default_notification_channel_id'),
      );
      expect(manifest, contains('default_notification_icon'));
      expect(manifest, contains('@drawable/ic_stat_petspace'));
    });

    test('canonical SQL and migration encode preference and idempotency', () {
      final setup = _read('../supabase/petspace_setup.sql');
      final migration = _read(
        '../supabase/releases/20260804_fcm_notification_release.sql',
      );

      for (final source in <String>[setup, migration]) {
        expect(source, contains('notification_type_preference_enabled'));
        expect(source, contains('create_notification'));
        expect(source, contains('event_key'));
        expect(source, contains("'notification_id'"));
        expect(source, contains('enabled_health_alert'));
        expect(source, contains('nullif(btrim('));
      }
      expect(migration, contains('TO service_role'));
      expect(
        migration,
        isNot(
          contains(
            'GRANT EXECUTE ON FUNCTION public.create_notification'
            '\n  TO authenticated',
          ),
        ),
      );
    });
  });
}
