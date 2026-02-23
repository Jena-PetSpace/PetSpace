import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/follow.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class FollowUserParams {
  final String followerId;
  final String followingId;

  const FollowUserParams({
    required this.followerId,
    required this.followingId,
  });
}

class FollowUser extends UseCase<Follow, FollowUserParams> {
  final SocialRepository repository;

  FollowUser(this.repository);

  @override
  Future<Either<Failure, Follow>> call(FollowUserParams params) async {
    return await repository.followUser(params.followerId, params.followingId);
  }
}