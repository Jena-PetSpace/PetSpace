import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/profile/presentation/pages/notification_settings_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';

class _Repository extends Mock implements SocialRepository {}

const _serverSettings = <String, dynamic>{
  'enabled_push': true,
  'enabled_like': true,
  'enabled_comment': true,
  'enabled_follow': true,
  'enabled_mention': true,
  'enabled_system': true,
};

Widget _host({
  required SocialRepository repository,
  required Future<bool> Function() permissionLoader,
}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(
        home: NotificationSettingsPage(
          repository: repository,
          currentUserIdProvider: () => 'viewer',
          notificationPermissionLoader: permissionLoader,
        ),
      ),
    );

void main() {
  late _Repository repository;

  setUp(() {
    repository = _Repository();
    SharedPreferences.setMockInitialValues({
      'notification_chat': false,
    });
  });

  testWidgets(
      'shows only canonical notification controls and preserves chat cache', (
    tester,
  ) async {
    when(
      () => repository.getNotificationPreferences('viewer'),
    ).thenAnswer(
      (_) async => const Right<Failure, Map<String, dynamic>?>(
        _serverSettings,
      ),
    );

    await tester.pumpWidget(
      _host(repository: repository, permissionLoader: () async => true),
    );
    await tester.pumpAndSettle();

    for (final label in ['푸시 알림', '좋아요', '댓글', '팔로우', '멘션', '시스템']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('채팅'), findsNothing);
    expect(find.text('새 채팅 메시지가 오면 알림'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notification_chat'), isFalse);
  });

  testWidgets('keeps cached values when the server load fails', (tester) async {
    SharedPreferences.setMockInitialValues({
      'notification_chat': true,
      'notification_like': false,
    });
    when(
      () => repository.getNotificationPreferences('viewer'),
    ).thenAnswer(
      (_) async => const Left<Failure, Map<String, dynamic>?>(
        NetworkFailure(message: 'private transport detail'),
      ),
    );

    await tester.pumpWidget(
      _host(repository: repository, permissionLoader: () async => true),
    );
    await tester.pumpAndSettle();

    final likeTile = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('좋아요'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(likeTile.value, isFalse);
    expect(find.textContaining('private transport detail'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('notification_chat'), isTrue);
  });

  testWidgets('rolls back a failed canonical server save with a safe message', (
    tester,
  ) async {
    when(
      () => repository.getNotificationPreferences('viewer'),
    ).thenAnswer(
      (_) async => const Right<Failure, Map<String, dynamic>?>(
        _serverSettings,
      ),
    );
    when(
      () => repository.upsertNotificationPreference(
        userId: 'viewer',
        column: 'enabled_like',
        value: false,
      ),
    ).thenAnswer(
      (_) async => const Left<Failure, void>(
        ServerFailure(message: 'private database detail'),
      ),
    );

    await tester.pumpWidget(
      _host(repository: repository, permissionLoader: () async => true),
    );
    await tester.pumpAndSettle();

    final likeTile = find.ancestor(
      of: find.text('좋아요'),
      matching: find.byType(SwitchListTile),
    );
    await tester
        .tap(find.descendant(of: likeTile, matching: find.byType(Switch)));
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(likeTile).value, isTrue);
    expect(find.textContaining('설정 동기화에 실패했습니다.'), findsOneWidget);
    expect(find.textContaining('private database detail'), findsNothing);
    verify(
      () => repository.upsertNotificationPreference(
        userId: 'viewer',
        column: 'enabled_like',
        value: false,
      ),
    ).called(1);
  });

  testWidgets('rechecks the injected system permission when the app resumes', (
    tester,
  ) async {
    var permissionChecks = 0;
    when(
      () => repository.getNotificationPreferences('viewer'),
    ).thenAnswer(
      (_) async => const Right<Failure, Map<String, dynamic>?>(
        _serverSettings,
      ),
    );

    await tester.pumpWidget(
      _host(
        repository: repository,
        permissionLoader: () async => permissionChecks++ > 0,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('시스템 알림이 꺼져 있어요'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(permissionChecks, 2);
    expect(find.text('시스템 알림이 꺼져 있어요'), findsNothing);
  });
}
