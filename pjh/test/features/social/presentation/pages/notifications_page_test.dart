import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/notification.dart'
    as app;
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/notifications_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/notifications_page.dart';

class _MockRepository extends Mock implements SocialRepository {}

class _MockNotificationsBloc
    extends MockBloc<NotificationsEvent, NotificationsState>
    implements NotificationsBloc {}

class _FakeNotificationsEvent extends Fake implements NotificationsEvent {}

void main() {
  final now = DateTime(2026, 7, 22, 14);

  app.Notification unreadNotification() => app.Notification(
        id: 'notification-1',
        userId: 'user-1',
        senderId: 'sender-1',
        senderName: '보리네',
        type: app.NotificationType.like,
        title: '좋아요',
        body: '게시물을 좋아합니다.',
        postId: 'post-1',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

  setUpAll(() => registerFallbackValue(_FakeNotificationsEvent()));

  Future<NotificationsLoaded> loadBloc(
    NotificationsBloc bloc,
    _MockRepository repository,
  ) async {
    when(
      () => repository.getUserNotifications(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
        lastNotificationId: any(named: 'lastNotificationId'),
      ),
    ).thenAnswer((_) async => Right([unreadNotification()]));
    final loaded =
        bloc.stream.firstWhere((state) => state is NotificationsLoaded);
    bloc.add(const LoadNotificationsRequested(userId: 'user-1'));
    return await loaded as NotificationsLoaded;
  }

  test('모두 읽음은 서버 성공 전까지 unread 상태를 유지한다', () async {
    final repository = _MockRepository();
    final bloc = NotificationsBloc(socialRepository: repository);
    addTearDown(bloc.close);
    await loadBloc(bloc, repository);

    final result = Completer<Either<Failure, void>>();
    when(() => repository.markAllNotificationsAsRead('user-1'))
        .thenAnswer((_) => result.future);
    final pending = bloc.stream.firstWhere(
      (state) => state is NotificationsLoaded && state.isMarkingAllRead,
    );
    bloc.add(const MarkAllNotificationsAsReadRequested(userId: 'user-1'));
    final pendingState = await pending as NotificationsLoaded;

    expect(pendingState.notifications.single.isRead, isFalse);
    final completed = bloc.stream.firstWhere(
      (state) => state is NotificationsLoaded && state.allReadSuccessCount == 1,
    );
    result.complete(const Right(null));
    final completedState = await completed as NotificationsLoaded;

    expect(completedState.notifications.single.isRead, isTrue);
    expect(completedState.isMarkingAllRead, isFalse);
  });

  test('서버 실패는 unread와 안전한 오류만 남긴다', () async {
    final repository = _MockRepository();
    final bloc = NotificationsBloc(socialRepository: repository);
    addTearDown(bloc.close);
    await loadBloc(bloc, repository);
    when(() => repository.markAllNotificationsAsRead('user-1')).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'private RLS detail')),
    );

    final failed = bloc.stream.firstWhere(
      (state) => state is NotificationsLoaded && state.actionError != null,
    );
    bloc.add(const MarkAllNotificationsAsReadRequested(userId: 'user-1'));
    final failedState = await failed as NotificationsLoaded;

    expect(failedState.notifications.single.isRead, isFalse);
    expect(failedState.actionError, '모든 알림을 읽음으로 처리하지 못했어요.');
    expect(failedState.actionError, isNot(contains('private RLS detail')));
  });

  testWidgets('알림 화면은 오늘 그룹과 모두 읽음의 안전한 결과를 표시한다', (tester) async {
    final bloc = _MockNotificationsBloc();
    final states = StreamController<NotificationsState>();
    final loaded = NotificationsLoaded(
      notifications: [unreadNotification()],
      hasReachedMax: true,
    );
    when(() => bloc.state).thenReturn(loaded);
    whenListen(bloc, states.stream, initialState: loaded);
    addTearDown(states.close);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          home: NotificationsPage(
            userId: 'user-1',
            bloc: bloc,
            nowProvider: () => now,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('오늘'), findsOneWidget);
    await tester.tap(find.byKey(const Key('notifications_mark_all_read')));
    await tester.pump();
    verify(
      () => bloc.add(
        const MarkAllNotificationsAsReadRequested(userId: 'user-1'),
      ),
    ).called(1);

    states.add(
      loaded.copyWith(
        actionError: '모든 알림을 읽음으로 처리하지 못했어요.',
      ),
    );
    await tester.pump();

    expect(find.text('모든 알림을 읽음으로 처리하지 못했어요.'), findsOneWidget);
  });
}
