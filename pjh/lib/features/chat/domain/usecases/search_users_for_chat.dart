import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/chat_participant.dart';
import '../repositories/chat_repository.dart';

class SearchUsersForChat extends UseCase<List<ChatParticipant>, StringParams> {
  final ChatRepository repository;

  SearchUsersForChat(this.repository);

  @override
  Future<Either<Failure, List<ChatParticipant>>> call(StringParams params) {
    return repository.searchUsers(params.value);
  }
}
