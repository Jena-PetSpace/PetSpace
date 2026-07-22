import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/chat/domain/entities/chat_room.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/create_chat_room.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/get_chat_rooms.dart';
import 'package:meong_nyang_diary/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetChatRooms extends Mock implements GetChatRooms {}

class _MockCreateDirectChat extends Mock implements CreateDirectChat {}

class _MockCreateGroupChat extends Mock implements CreateGroupChat {}

ChatRoom _room(String id) => ChatRoom(
      id: id,
      type: ChatRoomType.direct,
      createdBy: 'user-1',
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
    );

void main() {
  late _MockGetChatRooms getRooms;
  late _MockCreateDirectChat createDirect;
  late _MockCreateGroupChat createGroup;
  late ChatRoomsBloc bloc;

  setUpAll(() {
    registerFallbackValue(const GetChatRoomsParams(userId: 'fallback'));
    registerFallbackValue(const CreateDirectChatParams(
      currentUserId: 'fallback',
      otherUserId: 'fallback',
    ));
    registerFallbackValue(const CreateGroupChatParams(
      name: 'fallback',
      creatorId: 'fallback',
      memberIds: ['fallback'],
    ));
  });

  setUp(() {
    getRooms = _MockGetChatRooms();
    createDirect = _MockCreateDirectChat();
    createGroup = _MockCreateGroupChat();
    bloc = ChatRoomsBloc(
      getChatRooms: getRooms,
      createDirectChat: createDirect,
      createGroupChat: createGroup,
    );
  });

  tearDown(() => bloc.close());

  test('새로고침 실패는 기존 방 목록을 보존한다', () async {
    var loads = 0;
    when(() => getRooms(any())).thenAnswer((_) async {
      loads++;
      if (loads == 1) return Right([_room('room-1')]);
      return const Left(ServerFailure(message: '새로고침 실패'));
    });

    bloc.add(const ChatRoomsLoadRequested(userId: 'user-1'));
    await bloc.stream.firstWhere((state) => state is ChatRoomsLoaded);
    bloc.add(const ChatRoomsRefreshRequested(userId: 'user-1'));
    final failed = await bloc.stream
        .where((state) => state is ChatRoomsLoaded)
        .cast<ChatRoomsLoaded>()
        .firstWhere((state) => state.refreshErrorMessage != null);

    expect(failed.rooms.single.id, 'room-1');
    expect(failed.isRefreshing, isFalse);
    expect(failed.refreshErrorMessage, '새로고침 실패');
  });

  test('생성 중 중복 요청은 한 번만 실행한다', () async {
    final request = Completer<Either<Failure, ChatRoom>>();
    when(() => createDirect(any())).thenAnswer((_) => request.future);

    const event = ChatRoomsCreateDirectRequested(
      currentUserId: 'user-1',
      otherUserId: 'user-2',
    );
    bloc.add(event);
    await bloc.stream.firstWhere((state) => state is ChatRoomCreating);
    bloc.add(event);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    request.complete(Right(_room('room-1')));
    await bloc.stream.firstWhere((state) => state is ChatRoomCreated);

    verify(() => createDirect(any())).called(1);
  });
}
