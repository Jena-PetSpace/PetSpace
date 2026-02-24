import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class SendMessage extends UseCase<ChatMessage, SendMessageParams> {
  final ChatRepository repository;

  SendMessage(this.repository);

  @override
  Future<Either<Failure, ChatMessage>> call(SendMessageParams params) {
    return repository.sendMessage(
      roomId: params.roomId,
      senderId: params.senderId,
      content: params.content,
    );
  }
}

class SendMessageParams extends Equatable {
  final String roomId;
  final String senderId;
  final String content;

  const SendMessageParams({
    required this.roomId,
    required this.senderId,
    required this.content,
  });

  @override
  List<Object?> get props => [roomId, senderId, content];
}
