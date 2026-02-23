import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class UnlikePostParams {
  final String postId;
  final String userId;

  const UnlikePostParams({
    required this.postId,
    required this.userId,
  });
}

class UnlikePost extends UseCase<void, UnlikePostParams> {
  final SocialRepository repository;

  UnlikePost(this.repository);

  @override
  Future<Either<Failure, void>> call(UnlikePostParams params) async {
    return await repository.unlikePost(params.postId, params.userId);
  }
}
