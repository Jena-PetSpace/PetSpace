import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/core/usecases/usecase.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/chat/domain/entities/chat_participant.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/search_users_for_chat.dart';
import 'package:meong_nyang_diary/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart';
import 'package:meong_nyang_diary/features/chat/presentation/pages/create_chat_page.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/follow.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockChatRoomsBloc extends MockBloc<ChatRoomsEvent, ChatRoomsState>
    implements ChatRoomsBloc {}

class _MockSocialRepository extends Mock implements SocialRepository {}

class _MockSearchUsersForChat extends Mock implements SearchUsersForChat {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _FakeChatRoomsEvent extends Fake implements ChatRoomsEvent {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockChatRoomsBloc chatRoomsBloc;
  late _MockSocialRepository socialRepository;
  late _MockSearchUsersForChat searchUsers;

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

  Follow follow(String id, String name) => Follow(
        id: 'follow-$id',
        followerId: 'user-1',
        followingId: id,
        followerName: '정현',
        followingName: name,
        status: FollowStatus.accepted,
        createdAt: DateTime(2026, 7, 20),
      );

  ChatParticipant participant(String id, String name) => ChatParticipant(
        id: 'participant-$id',
        roomId: '',
        userId: id,
        displayName: name,
        joinedAt: DateTime(2026, 7, 20),
        lastReadAt: DateTime(2026, 7, 20),
      );

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(_FakeChatRoomsEvent());
    registerFallbackValue(const StringParams(value: 'fallback'));
  });

  setUp(() async {
    await sl.reset();
    authBloc = _MockAuthBloc();
    chatRoomsBloc = _MockChatRoomsBloc();
    socialRepository = _MockSocialRepository();
    searchUsers = _MockSearchUsersForChat();

    when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(user),
    );
    when(() => chatRoomsBloc.state).thenReturn(ChatRoomsInitial());
    whenListen(
      chatRoomsBloc,
      const Stream<ChatRoomsState>.empty(),
      initialState: ChatRoomsInitial(),
    );
    when(() => socialRepository.getFollowing('user-1')).thenAnswer(
      (_) async => Right([
        follow('user-2', '콩떡이네'),
        follow('user-3', '해피 보호자'),
      ]),
    );
    when(() => searchUsers(any())).thenAnswer(
      (_) async => Right([
        participant('user-4', '모카네'),
      ]),
    );

    sl.registerSingleton<SocialRepository>(socialRepository);
    sl.registerSingleton<SearchUsersForChat>(searchUsers);
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<ChatRoomsBloc>.value(value: chatRoomsBloc),
            ],
            child: const CreateChatPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('2명을 선택하면 요약·그룹 이름·고정 생성 버튼을 표시한다', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('chat_user_user-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_user_user-3')));
    await tester.pump();

    expect(find.byKey(const Key('chat_selected_summary')), findsOneWidget);
    expect(find.text('2명 선택'), findsOneWidget);
    expect(find.byKey(const Key('chat_group_name_field')), findsOneWidget);
    expect(find.text('그룹 채팅을 만듭니다'), findsOneWidget);
    expect(find.text('선택 · 비워두면 참여자 이름으로 만들어요.'), findsOneWidget);
    expect(find.text('그룹 만들기'), findsOneWidget);
  });

  testWidgets('한 명 선택 시 상대 이름과 1:1 목적을 CTA에 표시한다', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('chat_user_user-2')));
    await tester.pump();

    expect(find.text('1:1 채팅을 시작합니다'), findsOneWidget);
    expect(find.text('콩떡이네와 채팅 시작'), findsOneWidget);
    expect(find.byKey(const Key('chat_group_name_field')), findsNothing);
  });

  testWidgets('생성 pending 중 선택과 검색의 중복 조작을 막는다', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('chat_user_user-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_user_user-3')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('chat_user_search_field')),
      '모카',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.byKey(const Key('chat_create_primary_action')));
    await tester.pump();

    final searchField = tester.widget<TextField>(
      find.byKey(const Key('chat_user_search_field')),
    );
    expect(searchField.enabled, isFalse);
    final clearButton = find.ancestor(
      of: find.byIcon(Icons.clear),
      matching: find.byType(IconButton),
    );
    expect(
      tester.widget<IconButton>(clearButton).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const Key('chat_create_primary_action')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('2명 선택'), findsOneWidget);
    verify(
      () => chatRoomsBloc.add(
        any(that: isA<ChatRoomsCreateGroupRequested>()),
      ),
    ).called(1);
  });

  testWidgets('검색은 300ms debounce 뒤 실행되고 결과를 표시한다', (tester) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('chat_user_search_field')),
      '모카',
    );
    await tester.pump(const Duration(milliseconds: 299));
    verifyNever(() => searchUsers(any()));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    verify(() => searchUsers(any())).called(1);
    expect(find.text('모카네'), findsOneWidget);
  });

  testWidgets('320x568과 150% 글자 크기에서 선택 UI가 overflow하지 않는다', (tester) async {
    await pumpPage(
      tester,
      size: const Size(320, 568),
      textScale: 1.5,
    );
    await tester.tap(find.byKey(const Key('chat_user_user-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_user_user-3')));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('320x568과 200% 글자 크기에서 그룹 생성 CTA가 유지된다', (tester) async {
    await pumpPage(
      tester,
      size: const Size(320, 568),
      textScale: 2,
    );
    await tester.tap(find.byKey(const Key('chat_user_user-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_user_user-3')));
    await tester.pump();

    expect(find.text('그룹 만들기'), findsOneWidget);
    expect(find.text('선택 · 비워두면 참여자 이름으로 만들어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('generation guard와 오류/빈 결과 분리 계약은 유지된다', () {
    final source =
        File('lib/features/chat/presentation/pages/create_chat_page.dart')
            .readAsStringSync();

    expect(source, contains('_searchGeneration'));
    expect(source, contains('generation != _searchGeneration'));
    expect(source, contains('_searchError'));
    expect(source, contains('chat_user_search_error'));
    expect(source, contains('chat_user_search_empty'));
  });
}
