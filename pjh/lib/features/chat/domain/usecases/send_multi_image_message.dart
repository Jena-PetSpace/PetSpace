import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class SendMultiImageMessage
    extends UseCase<ChatMessage, SendMultiImageMessageParams> {
  final ChatRepository repository;

  SendMultiImageMessage(this.repository);

  @override
  Future<Either<Failure, ChatMessage>> call(
    SendMultiImageMessageParams params,
  ) {
    return repository.sendMultiImageMessage(
      roomId: params.roomId,
      senderId: params.senderId,
      images: params.images,
    );
  }
}

class SendMultiImageMessageParams extends Equatable {
  final String roomId;
  final String senderId;
  final List<File> images;

  const SendMultiImageMessageParams({
    required this.roomId,
    required this.senderId,
    required this.images,
  });

  @override
  List<Object?> get props => [
        roomId,
        senderId,
        images.map((file) => file.path).toList(growable: false),
      ];
}
