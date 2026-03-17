import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/post.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class GetFeedParams {
  final String? userId;
  final int limit;
  final String? lastPostId;
  final bool followingOnly;

  const GetFeedParams({
    this.userId,
    this.limit = 20,
    this.lastPostId,
    this.followingOnly = false,
  });
}

class GetFeed extends UseCase<List<Post>, GetFeedParams> {
  final SocialRepository repository;

  GetFeed(this.repository);

  @override
  Future<Either<Failure, List<Post>>> call(GetFeedParams params) async {
    return await repository.getFeed(
      userId: params.userId,
      limit: params.limit,
      lastPostId: params.lastPostId,
      followingOnly: params.followingOnly,
    );
  }
}