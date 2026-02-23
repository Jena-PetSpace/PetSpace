import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/comment.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class GetCommentsParams {
  final String postId;
  final int limit;
  final String? lastCommentId;

  const GetCommentsParams({
    required this.postId,
    this.limit = 20,
    this.lastCommentId,
  });
}

class GetComments extends UseCase<List<Comment>, GetCommentsParams> {
  final SocialRepository repository;

  GetComments(this.repository);

  @override
  Future<Either<Failure, List<Comment>>> call(GetCommentsParams params) async {
    return await repository.getPostComments(
      postId: params.postId,
      limit: params.limit,
      lastCommentId: params.lastCommentId,
    );
  }
}