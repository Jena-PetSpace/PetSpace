import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

class LeaveChatRoom extends UseCase<void, LeaveChatRoomParams> {
  final ChatRepository repository;

  LeaveChatRoom(this.repository);

  @override
  Future<Either<Failure, void>> call(LeaveChatRoomParams params) {
    return repository.leaveChatRoom(
      roomId: params.roomId,
      userId: params.userId,
    );
  }
}

class LeaveChatRoomParams extends Equatable {
  final String roomId;
  final String userId;

  const LeaveChatRoomParams({
    required this.roomId,
    required this.userId,
  });

  @override
  List<Object?> get props => [roomId, userId];
}
