import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/services/local_notification_service.dart';
import 'package:meong_nyang_diary/features/health/presentation/pages/health_alert_settings_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalNotificationService extends Mock
    implements LocalNotificationService {}

Widget _wrap(
  LocalNotificationService service, {
  double textScale = 1,
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: HealthAlertSettingsPage(notificationService: service),
    ),
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  LocalNotificationService service, {
  Size surface = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap(service, textScale: textScale));
  await tester.pump();
}

void _stub(
  _MockLocalNotificationService service,
  HealthAlertScheduleResult result,
) {
  when(
    () => service.scheduleHealthAlert(
      id: any(named: 'id'),
      title: any(named: 'title'),
      body: any(named: 'body'),
      scheduledDate: any(named: 'scheduledDate'),
    ),
  ).thenAnswer((_) async => result);
}

void main() {
  late _MockLocalNotificationService service;

  setUp(() {
    service = _MockLocalNotificationService();
  });

  testWidgets('only the complete device notification check is exposed',
      (tester) async {
    _stub(service, HealthAlertScheduleResult.scheduled);
    await _pumpPage(tester, service);

    expect(find.text('알림 수신 점검'), findsOneWidget);
    expect(find.text('자동 예정일 알림'), findsNothing);
    expect(find.text('준비 중'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('health_alert_test_button'))).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(const Key('health_alert_test_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('테스트 알림을 예약했어요'), findsOneWidget);
  });

  testWidgets('permission denial never displays the success message',
      (tester) async {
    _stub(service, HealthAlertScheduleResult.permissionDenied);
    await _pumpPage(tester, service);

    await tester.tap(find.byKey(const Key('health_alert_test_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('알림 권한을 허용'), findsOneWidget);
    expect(find.textContaining('테스트 알림을 예약했어요'), findsNothing);
    expect(find.byKey(const Key('health_alert_open_settings')), findsOneWidget);
  });

  testWidgets('320x568·글자 200%에서도 테스트 동작에 스크롤로 도달한다', (tester) async {
    _stub(service, HealthAlertScheduleResult.failed);
    await _pumpPage(
      tester,
      service,
      surface: const Size(320, 568),
      textScale: 2,
    );

    final action = find.byKey(const Key('health_alert_test_button'));
    await tester.ensureVisible(action);
    await tester.pump();

    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
