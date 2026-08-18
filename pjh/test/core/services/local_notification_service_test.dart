import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/services/local_notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSupabaseClient supabase;

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

  setUp(() {
    supabase = _MockSupabaseClient();
  });

  test('health alert reports scheduled only after the platform call succeeds',
      () async {
    var calls = 0;
    final service = LocalNotificationService.forTest(
      supabase: supabase,
      healthAlertScheduleDelegate: ({
        required id,
        required title,
        required body,
        required scheduledDate,
        payload,
      }) async {
        calls++;
      },
    );

    final result = await service.scheduleHealthAlert(
      id: 1,
      title: 'test',
      body: 'body',
      scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
    );

    expect(result, HealthAlertScheduleResult.scheduled);
    expect(calls, 1);
  });

  test('permission denial and unavailable service never call the scheduler',
      () async {
    var calls = 0;
    Future<void> scheduler({
      required int id,
      required String title,
      required String body,
      required scheduledDate,
      String? payload,
    }) async {
      calls++;
    }

    final denied = LocalNotificationService.forTest(
      supabase: supabase,
      healthAlertScheduleDelegate: scheduler,
      permissionGranted: false,
    );
    final unavailable = LocalNotificationService.forTest(
      supabase: supabase,
      healthAlertScheduleDelegate: scheduler,
      initialized: false,
    );

    expect(
      await denied.scheduleHealthAlert(
        id: 1,
        title: 'test',
        body: 'body',
        scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
      ),
      HealthAlertScheduleResult.permissionDenied,
    );
    expect(
      await unavailable.scheduleHealthAlert(
        id: 2,
        title: 'test',
        body: 'body',
        scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
      ),
      HealthAlertScheduleResult.unavailable,
    );
    expect(calls, 0);
  });

  test('permission is checked again before retrying in the same app session',
      () async {
    var permissionChecks = 0;
    var schedulerCalls = 0;
    final service = LocalNotificationService.forTest(
      supabase: supabase,
      permissionGranted: false,
      permissionDelegate: () async => ++permissionChecks >= 2,
      healthAlertScheduleDelegate: ({
        required id,
        required title,
        required body,
        required scheduledDate,
        payload,
      }) async {
        schedulerCalls++;
      },
    );

    Future<HealthAlertScheduleResult> schedule() => service.scheduleHealthAlert(
          id: 1,
          title: 'test',
          body: 'body',
          scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
        );

    expect(await schedule(), HealthAlertScheduleResult.permissionDenied);
    expect(await schedule(), HealthAlertScheduleResult.scheduled);
    expect(permissionChecks, 2);
    expect(schedulerCalls, 1);
  });

  test('past date and platform failure return explicit non-success outcomes',
      () async {
    final service = LocalNotificationService.forTest(
      supabase: supabase,
      healthAlertScheduleDelegate: ({
        required id,
        required title,
        required body,
        required scheduledDate,
        payload,
      }) async {
        throw StateError('platform failure');
      },
    );

    expect(
      await service.scheduleHealthAlert(
        id: 1,
        title: 'test',
        body: 'body',
        scheduledDate: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      HealthAlertScheduleResult.invalidDate,
    );
    expect(
      await service.scheduleHealthAlert(
        id: 2,
        title: 'test',
        body: 'body',
        scheduledDate: DateTime.now().add(const Duration(minutes: 1)),
      ),
      HealthAlertScheduleResult.failed,
    );
  });

  test('foreground notification types use the matching Android channel', () {
    expect(
      LocalNotificationService.androidChannelIdForType('comment'),
      'social',
    );
    expect(
      LocalNotificationService.androidChannelIdForType('health_alert'),
      'health',
    );
    expect(
      LocalNotificationService.androidChannelIdForType('chat'),
      'chat',
    );
    expect(
      LocalNotificationService.androidChannelIdForType('emotion_analysis'),
      'system',
    );
  });
}
