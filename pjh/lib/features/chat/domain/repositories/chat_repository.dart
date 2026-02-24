import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/chat_room.dart';
import '../entities/chat_message.dart';
import '../entities/chat_participant.dart';

abstract class ChatRepository {
  /// 사용자의 채팅방 목록 조회
  Future<Either<Failure, List<ChatRoom>>> getChatRooms(String userId);

  /// 채팅방 메시지 조회 (페이지네이션)
  Future<Either<Failure, List<ChatMessage>>> getChatMessages({
    required String roomId,
    int limit = 30,
    String? lastMessageId,
  });

  /// 텍스트 메시지 전송
  Future<Either<Failure, ChatMessage>> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
  });

  /// 이미지 메시지 전송
  Future<Either<Failure, ChatMessage>> sendImageMessage({
    required String roomId,
    required String senderId,
    required File imageFile,
  });

  /// 1:1 채팅방 생성 (기존 방 있으면 반환)
  Future<Either<Failure, ChatRoom>> createDirectChat({
    required String currentUserId,
    required String otherUserId,
  });

  /// 그룹 채팅방 생성
  Future<Either<Failure, ChatRoom>> createGroupChat({
    required String name,
    required String creatorId,
    required List<String> memberIds,
  });

  /// 마지막 읽은 시간 업데이트
  Future<Either<Failure, void>> updateLastRead({
    required String roomId,
    required String userId,
  });

  /// 전체 안읽은 메시지 수 조회
  Future<Either<Failure, int>> getTotalUnreadCount(String userId);

  /// 채팅용 유저 검색
  Future<Either<Failure, List<ChatParticipant>>> searchUsers(String query);

  /// 그룹 채팅방 나가기
  Future<Either<Failure, void>> leaveChatRoom({
    required String roomId,
    required String userId,
  });

  /// 그룹 채팅방 멤버 추가
  Future<Either<Failure, void>> addChatMembers({
    required String roomId,
    required List<String> memberIds,
  });
}
