import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/services/block_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/chat_room.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_participant.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  final BlockService blockService;

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
    required this.blockService,
  });

  ServerFailure _failure(
    String logMessage,
    Object error,
    String userMessage,
  ) {
    AppLogger().error(
      logMessage,
      tag: 'ChatRepository',
      error: error,
    );
    return ServerFailure(message: userMessage);
  }

  @override
  Future<Either<Failure, List<ChatRoom>>> getChatRooms(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.getChatRooms(userId);
      final blocked = (await blockService.getBlockedUserIds()).toSet();
      final rooms = result.map((m) => m.toEntity()).where((room) {
        // 1:1 방에서 상대가 차단 대상이면 목록에서 숨김. (그룹은 유지)
        final other = room.getOtherParticipant(userId);
        return other == null || !blocked.contains(other.userId);
      }).toList();
      return Right(rooms);
    } catch (e) {
      return Left(_failure(
        '채팅방 목록 조회 실패',
        e,
        '채팅방 목록을 불러오지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getChatMessages({
    required String roomId,
    int limit = 30,
    String? lastMessageId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.getChatMessages(
        roomId: roomId,
        limit: limit,
        lastMessageId: lastMessageId,
      );
      // 차단한 사용자의 메시지 제외 (초기/추가 로드).
      final blocked = (await blockService.getBlockedUserIds()).toSet();
      return Right(result
          .where((m) => !blocked.contains(m.senderId))
          .map((m) => m.toEntity())
          .toList());
    } catch (e) {
      return Left(_failure(
        '채팅 메시지 조회 실패',
        e,
        '메시지를 불러오지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.sendMessage(
        roomId: roomId,
        senderId: senderId,
        content: content,
      );
      return Right(result.toEntity());
    } catch (e) {
      return Left(_failure(
        '텍스트 메시지 전송 실패',
        e,
        '메시지 전송에 실패했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> sendImageMessage({
    required String roomId,
    required String senderId,
    required File imageFile,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.sendImageMessage(
        roomId: roomId,
        senderId: senderId,
        imageFile: imageFile,
      );
      return Right(result.toEntity());
    } catch (e) {
      return Left(_failure(
        '이미지 메시지 전송 실패',
        e,
        '이미지 전송에 실패했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, ChatRoom>> createDirectChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.createDirectChat(
        currentUserId: currentUserId,
        otherUserId: otherUserId,
      );
      return Right(result.toEntity());
    } catch (e) {
      return Left(_failure(
        '1:1 채팅방 생성 실패',
        e,
        '채팅방 생성에 실패했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, ChatRoom>> createGroupChat({
    required String name,
    required String creatorId,
    required List<String> memberIds,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.createGroupChat(
        name: name,
        creatorId: creatorId,
        memberIds: memberIds,
      );
      return Right(result.toEntity());
    } catch (e) {
      return Left(_failure(
        '그룹 채팅방 생성 실패',
        e,
        '그룹 채팅방 생성에 실패했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> updateLastRead({
    required String roomId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      await remoteDataSource.updateLastRead(roomId: roomId, userId: userId);
      return const Right(null);
    } catch (e) {
      return Left(_failure(
        '읽음 상태 업데이트 실패',
        e,
        '읽음 상태를 업데이트하지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, int>> getTotalUnreadCount(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.getTotalUnreadCount(userId);
      return Right(result);
    } catch (e) {
      return Left(_failure(
        '안읽은 메시지 수 조회 실패',
        e,
        '안읽은 메시지 수를 불러오지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, List<ChatParticipant>>> searchUsers(
      String query) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.searchUsers(query);
      return Right(result.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(_failure(
        '채팅 사용자 검색 실패',
        e,
        '사용자 검색에 실패했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> leaveChatRoom({
    required String roomId,
    required String userId,
    String? leaverName,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      await remoteDataSource.leaveChatRoom(
          roomId: roomId, userId: userId, leaverName: leaverName);
      return const Right(null);
    } catch (e) {
      return Left(_failure(
        '채팅방 나가기 실패',
        e,
        '채팅방에서 나가지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> addChatMembers({
    required String roomId,
    required List<String> memberIds,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      await remoteDataSource.addChatMembers(
          roomId: roomId, memberIds: memberIds);
      return const Right(null);
    } catch (e) {
      return Left(_failure(
        '채팅방 멤버 추가 실패',
        e,
        '멤버를 추가하지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> updateChatRoomName({
    required String roomId,
    required String name,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      await remoteDataSource.updateChatRoomName(roomId: roomId, name: name);
      return const Right(null);
    } catch (e) {
      return Left(_failure(
        '채팅방 이름 변경 실패',
        e,
        '채팅방 이름을 변경하지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> updateChatRoomPhoto({
    required String roomId,
    required String photoUrl,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      await remoteDataSource.updateChatRoomPhoto(
          roomId: roomId, photoUrl: photoUrl);
      return const Right(null);
    } catch (e) {
      return Left(_failure(
        '채팅방 사진 URL 변경 실패',
        e,
        '채팅방 사진을 변경하지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, List<ChatParticipant>>> getRoomParticipants(
      String roomId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.getRoomParticipants(roomId);
      return Right(result.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(_failure(
        '채팅방 참여자 조회 실패',
        e,
        '참여자 목록을 불러오지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, String>> uploadChatRoomPhoto({
    required String roomId,
    required String userId,
    required File file,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final url = await remoteDataSource.uploadChatRoomPhoto(
          roomId: roomId, userId: userId, file: file);
      return Right(url);
    } catch (e) {
      return Left(_failure(
        '채팅방 사진 업로드 실패',
        e,
        '채팅방 사진을 업로드하지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getChatRoomInfo(
      String roomId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final info = await remoteDataSource.getChatRoomInfo(roomId);
      return Right(info);
    } catch (e) {
      return Left(_failure(
        '채팅방 정보 조회 실패',
        e,
        '채팅방 정보를 불러오지 못했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, ChatMessage>> sendMultiImageMessage({
    required String roomId,
    required String senderId,
    required List<File> images,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.sendMultiImageMessage(
        roomId: roomId,
        senderId: senderId,
        imageFiles: images,
      );
      return Right(result.toEntity());
    } catch (e) {
      return Left(_failure(
        '다중 이미지 메시지 전송 실패',
        e,
        '사진 전송에 실패했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Stream<ChatMessage> subscribeToRoomMessages(String roomId) async* {
    // 실시간 INSERT마다 차단 목록을 새로 조회해 동적으로 반영한다.
    // (구독 시점 스냅샷이 아님 — 차단 액션이 캐시를 무효화하므로 다음 메시지부터 즉시 차단)
    await for (final model
        in remoteDataSource.subscribeToRoomMessages(roomId)) {
      final blocked = await blockService.getBlockedUserIds();
      if (blocked.contains(model.senderId)) continue; // 차단 사용자 메시지 드롭
      yield model.toEntity();
    }
  }

  @override
  Future<Either<Failure, void>> reportChatUser({
    required String reportedUserId,
    required String reporterId,
    required String reason,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      await remoteDataSource.reportChatUser(
        reportedUserId: reportedUserId,
        reporterId: reporterId,
        reason: reason,
      );
      return const Right(null);
    } catch (e) {
      return Left(_failure(
        '채팅 사용자 신고 접수 실패',
        e,
        '신고 접수에 실패했습니다. 다시 시도해주세요.',
      ));
    }
  }

  @override
  Future<Either<Failure, void>> reportChatMessage({
    required String messageId,
    required String reporterId,
    required String reason,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      await remoteDataSource.reportChatMessage(
        messageId: messageId,
        reporterId: reporterId,
        reason: reason,
      );
      return const Right(null);
    } catch (e) {
      return Left(_failure(
        '채팅 메시지 신고 접수 실패',
        e,
        '신고 접수에 실패했습니다. 다시 시도해주세요.',
      ));
    }
  }
}
