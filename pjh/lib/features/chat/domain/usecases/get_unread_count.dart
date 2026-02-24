import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

class GetUnreadCount extends UseCase<int, IdParams> {
  final ChatRepository repository;

  GetUnreadCount(this.repository);

  @override
  Future<Either<Failure, int>> call(IdParams params) {
    return repository.getTotalUnreadCount(params.id);
  }
}
