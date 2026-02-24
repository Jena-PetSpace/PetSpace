import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class SendImageMessage extends UseCase<ChatMessage, SendImageMessageParams> {
  final ChatRepository repository;

  SendImageMessage(this.repository);

  @override
  Future<Either<Failure, ChatMessage>> call(SendImageMessageParams params) {
    return repository.sendImageMessage(
      roomId: params.roomId,
      senderId: params.senderId,
      imageFile: params.imageFile,
    );
  }
}

class SendImageMessageParams extends Equatable {
  final String roomId;
  final String senderId;
  final File imageFile;

  const SendImageMessageParams({
    required this.roomId,
    required this.senderId,
    required this.imageFile,
  });

  @override
  List<Object?> get props => [roomId, senderId, imageFile.path];
}
