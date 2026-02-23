import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/social_repository.dart';

class DeletePost implements UseCase<void, DeletePostParams> {
  final SocialRepository repository;

  DeletePost(this.repository);

  @override
  Future<Either<Failure, void>> call(DeletePostParams params) async {
    return await repository.deletePost(params.postId);
  }
}

class DeletePostParams {
  final String postId;

  DeletePostParams({required this.postId});
}
