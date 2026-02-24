import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/chat_room.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_participant.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ChatRoom>>> getChatRooms(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.getChatRooms(userId);
      return Right(result.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(message: '채팅방 목록을 불러오지 못했습니다: $e'));
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
      return Right(result.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(message: '메시지를 불러오지 못했습니다: $e'));
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
      return Left(ServerFailure(message: '메시지 전송에 실패했습니다: $e'));
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
      return Left(ServerFailure(message: '이미지 전송에 실패했습니다: $e'));
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
      return Left(ServerFailure(message: '채팅방 생성에 실패했습니다: $e'));
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
      return Left(ServerFailure(message: '그룹 채팅방 생성에 실패했습니다: $e'));
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
      return Left(ServerFailure(message: '읽음 상태 업데이트에 실패했습니다: $e'));
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
      return Left(ServerFailure(message: '안읽은 메시지 수 조회에 실패했습니다: $e'));
    }
  }

  @override
  Future<Either<Failure, List<ChatParticipant>>> searchUsers(String query) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      final result = await remoteDataSource.searchUsers(query);
      return Right(result.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(message: '사용자 검색에 실패했습니다: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> leaveChatRoom({
    required String roomId,
    required String userId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.'));
    }
    try {
      await remoteDataSource.leaveChatRoom(roomId: roomId, userId: userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '채팅방 나가기에 실패했습니다: $e'));
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
      await remoteDataSource.addChatMembers(roomId: roomId, memberIds: memberIds);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '멤버 추가에 실패했습니다: $e'));
    }
  }
}
