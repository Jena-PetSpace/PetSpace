import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/chat/domain/entities/chat_room.dart';
import 'package:meong_nyang_diary/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart';
import 'package:meong_nyang_diary/features/chat/presentation/pages/chat_rooms_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockChatRoomsBloc extends MockBloc<ChatRoomsEvent, ChatRoomsState>
    implements ChatRoomsBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _FakeChatRoomsEvent extends Fake implements ChatRoomsEvent {}

void main() {
  late _MockAuthBloc authBloc;
  late _MockChatRoomsBloc chatRoomsBloc;

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

  ChatRoom room(
    String id,
    String name,
    String lastMessage, {
    int unreadCount = 0,
  }) {
    return ChatRoom(
      id: id,
      type: ChatRoomType.group,
      name: name,
      createdBy: 'user-1',
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
      lastMessage: lastMessage,
      lastMessageAt: DateTime(2026, 7, 20, 10),
      unreadCount: unreadCount,
    );
  }

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(_FakeChatRoomsEvent());
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    chatRoomsBloc = _MockChatRoomsBloc();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(user),
    );
  });

  Future<void> pumpPage(
    WidgetTester tester,
    ChatRoomsState state, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => chatRoomsBloc.state).thenReturn(state);
    whenListen(
      chatRoomsBloc,
      const Stream<ChatRoomsState>.empty(),
      initialState: state,
    );

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
            child: const ChatRoomsPage(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('채팅방 이름과 마지막 메시지로 로컬 검색한다', (tester) async {
    await pumpPage(
      tester,
      ChatRoomsLoaded(
        rooms: [
          room('room-1', '콩떡이네', '오늘 공원에서 만나요', unreadCount: 2),
          room('room-2', '해피 보호자', '산책 정보 고마워요'),
        ],
      ),
    );

    await tester.enterText(
      find.byKey(const Key('chat_rooms_search_field')),
      '공원',
    );
    await tester.pump();

    expect(find.text('콩떡이네'), findsOneWidget);
    expect(find.text('해피 보호자'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('chat_rooms_search_field')),
      '없는 방',
    );
    await tester.pump();

    expect(find.byKey(const Key('chat_rooms_search_empty')), findsOneWidget);
    expect(find.byKey(const Key('chat_rooms_initial_error')), findsNothing);
  });

  testWidgets('더보기는 44dp 이상이고 새로고침 실패에도 목록을 유지한다', (tester) async {
    await pumpPage(
      tester,
      ChatRoomsLoaded(
        rooms: [room('room-1', '콩떡이네', '안녕하세요')],
        refreshErrorMessage: '내부 오류 문자열',
      ),
    );

    final more = find.byKey(const Key('chat_room_more_room-1'));
    expect(more, findsOneWidget);
    final size = tester.getSize(more);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
    expect(find.text('콩떡이네'), findsOneWidget);
    expect(find.byKey(const Key('chat_rooms_refresh_error')), findsOneWidget);
    expect(find.text('내부 오류 문자열'), findsNothing);

    await tester.tap(find.byKey(const Key('chat_rooms_refresh_retry')));
    await tester.pump();
    verify(
      () => chatRoomsBloc.add(
        any(that: isA<ChatRoomsRefreshRequested>()),
      ),
    ).called(1);
  });

  testWidgets('320x568과 150% 글자 크기에서 overflow가 없다', (tester) async {
    await pumpPage(
      tester,
      ChatRoomsLoaded(
        rooms: [
          room(
            'room-1',
            '아주 긴 이름의 동네 반려동물 산책 모임',
            '아주 긴 마지막 메시지는 한 줄에서 자연스럽게 줄임표로 표시됩니다',
          ),
        ],
      ),
      size: const Size(320, 568),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
  });
}
