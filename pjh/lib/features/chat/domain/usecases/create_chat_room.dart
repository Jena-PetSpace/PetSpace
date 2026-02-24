import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/chat_room.dart';
import '../repositories/chat_repository.dart';

class CreateDirectChat extends UseCase<ChatRoom, CreateDirectChatParams> {
  final ChatRepository repository;

  CreateDirectChat(this.repository);

  @override
  Future<Either<Failure, ChatRoom>> call(CreateDirectChatParams params) {
    return repository.createDirectChat(
      currentUserId: params.currentUserId,
      otherUserId: params.otherUserId,
    );
  }
}

class CreateDirectChatParams extends Equatable {
  final String currentUserId;
  final String otherUserId;

  const CreateDirectChatParams({
    required this.currentUserId,
    required this.otherUserId,
  });

  @override
  List<Object?> get props => [currentUserId, otherUserId];
}

class CreateGroupChat extends UseCase<ChatRoom, CreateGroupChatParams> {
  final ChatRepository repository;

  CreateGroupChat(this.repository);

  @override
  Future<Either<Failure, ChatRoom>> call(CreateGroupChatParams params) {
    return repository.createGroupChat(
      name: params.name,
      creatorId: params.creatorId,
      memberIds: params.memberIds,
    );
  }
}

class CreateGroupChatParams extends Equatable {
  final String name;
  final String creatorId;
  final List<String> memberIds;

  const CreateGroupChatParams({
    required this.name,
    required this.creatorId,
    required this.memberIds,
  });

  @override
  List<Object?> get props => [name, creatorId, memberIds];
}
