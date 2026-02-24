import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

class AddChatMembers extends UseCase<void, AddChatMembersParams> {
  final ChatRepository repository;

  AddChatMembers(this.repository);

  @override
  Future<Either<Failure, void>> call(AddChatMembersParams params) {
    return repository.addChatMembers(
      roomId: params.roomId,
      memberIds: params.memberIds,
    );
  }
}

class AddChatMembersParams extends Equatable {
  final String roomId;
  final List<String> memberIds;

  const AddChatMembersParams({
    required this.roomId,
    required this.memberIds,
  });

  @override
  List<Object?> get props => [roomId, memberIds];
}
