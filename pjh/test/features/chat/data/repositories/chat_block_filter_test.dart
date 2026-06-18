import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/core/services/block_service.dart';
import 'package:meong_nyang_diary/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:meong_nyang_diary/features/chat/data/models/chat_message_model.dart';
import 'package:meong_nyang_diary/features/chat/data/models/chat_participant_model.dart';
import 'package:meong_nyang_diary/features/chat/data/models/chat_room_model.dart';
import 'package:meong_nyang_diary/features/chat/data/repositories/chat_repository_impl.dart';

class MockChatRemoteDataSource extends Mock implements ChatRemoteDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockBlockService extends Mock implements BlockService {}

ChatMessageModel _msg(String id, String senderId) => ChatMessageModel(
      id: id,
      roomId: 'room-1',
      senderId: senderId,
      content: 'hi',
      createdAt: DateTime(2026, 6, 14, 10),
    );

ChatParticipantModel _part(String userId) => ChatParticipantModel(
      id: 'p-$userId',
      roomId: 'room-1',
      userId: userId,
      joinedAt: DateTime(2026, 6, 1),
      lastReadAt: DateTime(2026, 6, 1),
    );

ChatRoomModel _directRoom(String id, List<String> memberIds) => ChatRoomModel(
      id: id,
      type: 'direct',
      createdBy: memberIds.first,
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
      participants: memberIds.map(_part).toList(),
    );

void main() {
  late MockChatRemoteDataSource ds;
  late MockNetworkInfo network;
  late MockBlockService block;
  late ChatRepositoryImpl repo;

  setUp(() {
    ds = MockChatRemoteDataSource();
    network = MockNetworkInfo();
    block = MockBlockService();
    repo = ChatRepositoryImpl(
      remoteDataSource: ds,
      networkInfo: network,
      blockService: block,
    );
    when(() => network.isConnected).thenAnswer((_) async => true);
  });

  // ── 초기 로드 필터 ─────────────────────────────────────────────────────────
  group('getChatMessages 차단 필터', () {
    test('차단 id 메시지는 결과에서 제외된다', () async {
      when(() => ds.getChatMessages(
            roomId: any(named: 'roomId'),
            limit: any(named: 'limit'),
            lastMessageId: any(named: 'lastMessageId'),
          )).thenAnswer((_) async => [
            _msg('m1', 'good-user'),
            _msg('m2', 'blocked-user'),
            _msg('m3', 'good-user'),
          ]);
      when(() => block.getBlockedUserIds(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => ['blocked-user']);

      final result = await repo.getChatMessages(roomId: 'room-1');

      final msgs = result.getOrElse(() => []);
      expect(msgs.map((m) => m.id), ['m1', 'm3']);
      expect(msgs.any((m) => m.senderId == 'blocked-user'), false);
    });

    test('차단 목록이 비면 전부 통과', () async {
      when(() => ds.getChatMessages(
            roomId: any(named: 'roomId'),
            limit: any(named: 'limit'),
            lastMessageId: any(named: 'lastMessageId'),
          )).thenAnswer((_) async => [_msg('m1', 'a'), _msg('m2', 'b')]);
      when(() => block.getBlockedUserIds(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => const []);

      final result = await repo.getChatMessages(roomId: 'room-1');
      expect(result.getOrElse(() => []).length, 2);
    });
  });

  // ── 실시간 스트림 필터 (동적 반영) ────────────────────────────────────────
  group('subscribeToRoomMessages 차단 필터(동적)', () {
    test('차단 사용자 실시간 메시지는 스트림에서 드롭', () async {
      when(() => ds.subscribeToRoomMessages(any())).thenAnswer(
        (_) => Stream.fromIterable([
          _msg('s1', 'good-user'),
          _msg('s2', 'blocked-user'),
          _msg('s3', 'good-user'),
        ]),
      );
      when(() => block.getBlockedUserIds(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => ['blocked-user']);

      final received = await repo.subscribeToRoomMessages('room-1').toList();
      expect(received.map((m) => m.id), ['s1', 's3']);
    });

    test('구독 시점 스냅샷이 아니라, 갱신된 차단 목록을 emission마다 반영', () async {
      when(() => ds.subscribeToRoomMessages(any())).thenAnswer(
        (_) => Stream.fromIterable([
          _msg('s1', 'later-blocked'), // 첫 emission: 아직 차단 전 → 통과
          _msg('s2', 'later-blocked'), // 두번째: 차단 후 → 드롭
        ]),
      );
      // 첫 조회는 빈 목록, 그 다음 조회부터는 차단 목록 반영(차단 액션 후 캐시 갱신 시뮬레이션)
      var callCount = 0;
      when(() => block.getBlockedUserIds(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? const [] : ['later-blocked'];
      });

      final received = await repo.subscribeToRoomMessages('room-1').toList();
      // 동적 반영이면 s1만 통과(첫 emission), s2는 드롭. 스냅샷이면 둘 다 통과(오답).
      expect(received.map((m) => m.id), ['s1']);
    });
  });

  // ── 방 목록 숨김 ──────────────────────────────────────────────────────────
  group('getChatRooms 차단 방 숨김', () {
    test('차단 상대와의 1:1 방은 목록에서 제외', () async {
      when(() => ds.getChatRooms(any())).thenAnswer((_) async => [
            _directRoom('room-A', ['me', 'good-user']),
            _directRoom('room-B', ['me', 'blocked-user']),
          ]);
      when(() => block.getBlockedUserIds(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => ['blocked-user']);

      final result = await repo.getChatRooms('me');
      final rooms = result.getOrElse(() => []);
      expect(rooms.map((r) => r.id), ['room-A']);
    });
  });
}
