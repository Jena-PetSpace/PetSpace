import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class LikePostParams {
  final String postId;
  final String userId;

  const LikePostParams({
    required this.postId,
    required this.userId,
  });
}

class LikePost extends UseCase<void, LikePostParams> {
  final SocialRepository repository;

  LikePost(this.repository);

  @override
  Future<Either<Failure, void>> call(LikePostParams params) async {
    return await repository.likePost(params.postId, params.userId);
  }
}