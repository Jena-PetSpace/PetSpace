import 'dart:convert';
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
import 'package:meong_nyang_diary/features/chat/domain/entities/chat_participant.dart';
import 'package:meong_nyang_diary/features/chat/domain/repositories/chat_repository.dart';
import 'package:meong_nyang_diary/features/chat/presentation/pages/chat_room_settings_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockChatRepository extends Mock implements ChatRepository {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

void main() {
  late _MockAuthBloc authBloc;
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

  ChatParticipant participant(
    String id,
    String name, {
    ChatRole role = ChatRole.member,
  }) {
    return ChatParticipant(
      id: 'participant-$id',
      roomId: 'room-1',
      userId: id,
      displayName: name,
      role: role,
      joinedAt: DateTime(2026, 7, 20),
      lastReadAt: DateTime(2026, 7, 20),
    );
  }

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
    registerFallbackValue(File('chat-room-photo-fallback.png'));
  });

  setUp(() async {
    await sl.reset();
    authBloc = _MockAuthBloc();
    repository = _MockChatRepository();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(user),
    );
    when(() => repository.getChatRoomInfo('room-1')).thenAnswer(
      (_) async => const Right({
        'name': '동네 산책 모임',
        'type': 'group',
        'avatar_url': null,
      }),
    );
    when(
      () => repository.updateChatRoomName(
        roomId: any(named: 'roomId'),
        name: any(named: 'name'),
      ),
    ).thenAnswer((_) async => const Right(null));

    sl.registerSingleton<ChatRepository>(repository);
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    List<ChatParticipant> participants, {
    Future<File?> Function(BuildContext context)? photoPicker,
  }) async {
    when(() => repository.getRoomParticipants('room-1'))
        .thenAnswer((_) async => Right(participants));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            initialRoute: '/settings',
            routes: {
              '/': (_) => const Scaffold(body: SizedBox.shrink()),
              '/settings': (_) => ChatRoomSettingsPage(
                    roomId: 'room-1',
                    roomName: '동네 산책 모임',
                    photoPicker: photoPicker,
                  ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('관리자는 실제 이름 변경이 있을 때만 저장할 수 있다', (tester) async {
    await pumpPage(tester, [
      participant('user-1', '정현', role: ChatRole.admin),
      participant('user-2', '콩떡이네'),
    ]);

    final nameFieldFinder = find.byKey(const Key('chat_room_name_field'));
    expect(tester.widget<TextField>(nameFieldFinder).enabled, isTrue);
    var saveButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('chat_room_save_button')),
    );
    expect(saveButton.onPressed, isNull);
    verifyNever(
      () => repository.updateChatRoomName(
        roomId: any(named: 'roomId'),
        name: any(named: 'name'),
      ),
    );

    await tester.enterText(nameFieldFinder, '동네 산책 모임');
    await tester.pump();
    saveButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('chat_room_save_button')),
    );
    expect(saveButton.onPressed, isNull);

    await tester.enterText(nameFieldFinder, '주말 산책 모임');
    await tester.pump();
    saveButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('chat_room_save_button')),
    );
    expect(saveButton.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('chat_room_save_button')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateChatRoomName(
        roomId: 'room-1',
        name: '주말 산책 모임',
      ),
    ).called(1);
  });

  testWidgets('사진만 변경하면 이름 갱신 없이 사진만 저장한다', (tester) async {
    final photo = File(
      '${Directory.systemTemp.path}/chat-room-photo-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    photo.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    addTearDown(() {
      if (photo.existsSync()) photo.deleteSync();
    });
    when(
      () => repository.uploadChatRoomPhoto(
        roomId: any(named: 'roomId'),
        userId: any(named: 'userId'),
        file: any(named: 'file'),
      ),
    ).thenAnswer(
      (_) async => const Right('https://example.com/chat-room.png'),
    );

    await pumpPage(
      tester,
      [
        participant('user-1', '정현', role: ChatRole.admin),
        participant('user-2', '콩떡이네'),
      ],
      photoPicker: (_) async => photo,
    );

    await tester.tap(find.byKey(const Key('chat_room_photo_picker')));
    await tester.pump();
    final saveButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('chat_room_save_button')),
    );
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('chat_room_save_button')));
    await tester.pumpAndSettle();

    verify(
      () => repository.uploadChatRoomPhoto(
        roomId: 'room-1',
        userId: 'user-1',
        file: photo,
      ),
    ).called(1);
    verifyNever(
      () => repository.updateChatRoomName(
        roomId: any(named: 'roomId'),
        name: any(named: 'name'),
      ),
    );
  });

  testWidgets('이름을 비우면 저장할 수 없다', (tester) async {
    await pumpPage(tester, [
      participant('user-1', '정현', role: ChatRole.admin),
      participant('user-2', '콩떡이네'),
    ]);

    await tester.enterText(
      find.byKey(const Key('chat_room_name_field')),
      '',
    );
    await tester.pump();

    final saveButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('chat_room_save_button')),
    );
    expect(saveButton.onPressed, isNull);
    verifyNever(
      () => repository.updateChatRoomName(
        roomId: any(named: 'roomId'),
        name: any(named: 'name'),
      ),
    );
  });

  testWidgets('일반 참여자는 편집·초대가 비활성이고 대상 메뉴와 나가기는 유지된다', (tester) async {
    await pumpPage(tester, [
      participant('user-1', '정현'),
      participant('user-2', '콩떡이네', role: ChatRole.admin),
    ]);

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('chat_room_name_field')),
          )
          .enabled,
      isFalse,
    );
    expect(find.byKey(const Key('chat_room_save_button')), findsNothing);
    expect(find.text('멤버 초대'), findsNothing);
    expect(
      find.byKey(const Key('chat_participant_menu_user-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('chat_participant_menu_user-2')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('chat_room_settings_content')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('채팅방 나가기'), findsOneWidget);
  });

  test('직접 Supabase 호출과 가짜 방별 알림 UI는 다시 생기지 않는다', () {
    final source = File(
      'lib/features/chat/presentation/pages/chat_room_settings_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Supabase.instance')));
    expect(source, isNot(contains('SwitchListTile')));
    expect(source, isNot(contains('chat_notification_')));
  });
}
