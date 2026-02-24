import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/chat_room.dart';
import '../repositories/chat_repository.dart';

class GetChatRooms extends UseCase<List<ChatRoom>, GetChatRoomsParams> {
  final ChatRepository repository;

  GetChatRooms(this.repository);

  @override
  Future<Either<Failure, List<ChatRoom>>> call(GetChatRoomsParams params) {
    return repository.getChatRooms(params.userId);
  }
}

class GetChatRoomsParams extends Equatable {
  final String userId;

  const GetChatRoomsParams({required this.userId});

  @override
  List<Object?> get props => [userId];
}
