import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class GetChatMessages extends UseCase<List<ChatMessage>, GetChatMessagesParams> {
  final ChatRepository repository;

  GetChatMessages(this.repository);

  @override
  Future<Either<Failure, List<ChatMessage>>> call(GetChatMessagesParams params) {
    return repository.getChatMessages(
      roomId: params.roomId,
      limit: params.limit,
      lastMessageId: params.lastMessageId,
    );
  }
}

class GetChatMessagesParams extends Equatable {
  final String roomId;
  final int limit;
  final String? lastMessageId;

  const GetChatMessagesParams({
    required this.roomId,
    this.limit = 30,
    this.lastMessageId,
  });

  @override
  List<Object?> get props => [roomId, limit, lastMessageId];
}
