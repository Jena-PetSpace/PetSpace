import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

class UpdateLastRead extends UseCase<void, UpdateLastReadParams> {
  final ChatRepository repository;

  UpdateLastRead(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateLastReadParams params) {
    return repository.updateLastRead(
      roomId: params.roomId,
      userId: params.userId,
    );
  }
}

class UpdateLastReadParams extends Equatable {
  final String roomId;
  final String userId;

  const UpdateLastReadParams({
    required this.roomId,
    required this.userId,
  });

  @override
  List<Object?> get props => [roomId, userId];
}
