import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/chat/domain/entities/chat_message.dart';
import 'package:meong_nyang_diary/features/chat/domain/entities/chat_participant.dart';
import 'package:meong_nyang_diary/features/chat/domain/repositories/chat_repository.dart';
import 'package:meong_nyang_diary/features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart';
import 'package:meong_nyang_diary/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockChatDetailBloc extends MockBloc<ChatDetailEvent, ChatDetailState>
    implements ChatDetailBloc {}

class _MockChatRepository extends Mock implements ChatRepository {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _FakeChatDetailEvent extends Fake implements ChatDetailEvent {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockChatDetailBloc chatDetailBloc;
  late _MockChatRepository repository;

  final user = User(
    uid: 'user-1',
    email: 'user@example.com',
    displayName: '정현',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    pets: const [],
    following: const [],
    followers: const [],
    settings: const UserSettings(
      notificationsEnabled: true,
      privacyLevel: PrivacyLevel.public,
      showEmotionAnalysisToPublic: false,
    ),
  );

  final participants = [
    ChatParticipant(
      id: 'participant-1',
      roomId: 'room-1',
      userId: 'user-1',
      displayName: '정현',
      joinedAt: DateTime(2026, 7, 20),
      lastReadAt: DateTime(2026, 7, 20, 15),
    ),
    ChatParticipant(
      id: 'participant-2',
      roomId: 'room-1',
      userId: 'user-2',
      displayName: '콩떡이네',
      joinedAt: DateTime(2026, 7, 20),
      lastReadAt: DateTime(2026, 7, 20, 15),
    ),
  ];

  ChatMessage message() => ChatMessage(
        id: 'message-1',
        roomId: 'room-1',
        senderId: 'user-2',
        senderName: '콩떡이네',
        content: '기존 메시지는 유지됩니다.',
        createdAt: DateTime(2026, 7, 20, 14),
      );

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(_FakeChatDetailEvent());
  });

  setUp(() async {
    await sl.reset();
    authBloc = _MockAuthBloc();
    chatDetailBloc = _MockChatDetailBloc();
    repository = _MockChatRepository();

    when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(user),
    );
    when(() => repository.getRoomParticipants('room-1'))
        .thenAnswer((_) async => Right(participants));
    when(() => repository.getChatRoomInfo('room-1')).thenAnswer(
      (_) async => const Right({
        'name': '콩떡이네',
        'type': 'direct',
      }),
    );
    when(() => repository.subscribeToRoomMessages('room-1'))
        .thenAnswer((_) => const Stream<ChatMessage>.empty());

    sl.registerSingleton<ChatRepository>(repository);
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    ChatDetailState state, {
    String roomType = 'direct',
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    when(() => chatDetailBloc.state).thenReturn(state);
    whenListen(
      chatDetailBloc,
      const Stream<ChatDetailState>.empty(),
      initialState: state,
    );
    when(() => repository.getChatRoomInfo('room-1')).thenAnswer(
      (_) async => Right({
        'name': roomType == 'direct' ? '콩떡이네' : '동네 산책 모임',
        'type': roomType,
      }),
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ChatDetailBloc>.value(value: chatDetailBloc),
            ],
            child: const ChatDetailPage(roomId: 'room-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('전송 실패는 안전한 인라인 복구 카드만 표시한다', (tester) async {
    const rawError = 'PostgrestException: secret_table token=abc';
    final state = ChatDetailLoaded(
      messages: [message()],
      sendOutcome: const ChatSendOutcome(
        requestId: 1,
        kind: ChatSendKind.text,
        status: ChatSendStatus.failure,
        roomId: 'room-1',
        senderId: 'user-1',
        text: '보존할 메시지',
        errorMessage: rawError,
      ),
    );
    await pumpPage(tester, state);

    expect(find.byKey(const Key('chat_send_failure_card')), findsOneWidget);
    expect(find.text('메시지를 보내지 못했어요.'), findsOneWidget);
    expect(find.text(rawError), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(const Key('chat_send_retry')));
    await tester.pump();
    verify(
      () => chatDetailBloc.add(
        any(that: isA<ChatDetailRetryLastSendRequested>()),
      ),
    ).called(1);
  });

  testWidgets('과거 메시지 실패는 기존 메시지와 인라인 재시도를 함께 유지한다', (tester) async {
    final state = ChatDetailLoaded(
      messages: [message()],
      loadMoreError: '내부 페이지네이션 오류',
    );
    await pumpPage(tester, state);

    expect(find.text('기존 메시지는 유지됩니다.'), findsOneWidget);
    expect(find.byKey(const Key('chat_load_more_error')), findsOneWidget);
    expect(find.text('내부 페이지네이션 오류'), findsNothing);

    await tester.tap(find.byKey(const Key('chat_load_more_retry')));
    await tester.pump();
    verify(
      () => chatDetailBloc.add(
        any(that: isA<ChatDetailLoadMoreRequested>()),
      ),
    ).called(1);
  });

  testWidgets('상단 신고·차단 메뉴는 직접방에서만 노출한다', (tester) async {
    await pumpPage(
      tester,
      ChatDetailLoaded(messages: [message()]),
    );
    expect(find.byKey(const Key('chat_direct_user_menu')), findsOneWidget);

    await pumpPage(
      tester,
      ChatDetailLoaded(messages: [message()]),
      roomType: 'group',
    );
    expect(find.byKey(const Key('chat_direct_user_menu')), findsNothing);
  });

  testWidgets('가장 최근 내 메시지는 상대가 모두 읽으면 읽음 상태를 표시한다', (tester) async {
    final mine = ChatMessage(
      id: 'message-mine',
      roomId: 'room-1',
      senderId: 'user-1',
      content: '주말에 같이 걸을까요?',
      createdAt: DateTime(2026, 7, 20, 15),
    );
    await pumpPage(
      tester,
      ChatDetailLoaded(messages: [mine, message()]),
    );

    expect(find.text('읽음'), findsOneWidget);
  });

  test('이미지 전송과 실시간 보강은 C1A BLoC 계약을 유지한다', () {
    final source =
        File('lib/features/chat/presentation/pages/chat_detail_page.dart')
            .readAsStringSync();

    expect(source, contains('ChatDetailSendMultipleImagesRequested'));
    expect(source, isNot(contains('sendMultiImageMessage(')));
    expect(source, contains('senderName: sender.displayName'));
    expect(source, contains('_scheduleReadAndParticipantsRefresh'));
  });
}
