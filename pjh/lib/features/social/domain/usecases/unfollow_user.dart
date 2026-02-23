import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class UnfollowUserParams {
  final String followerId;
  final String followingId;

  const UnfollowUserParams({
    required this.followerId,
    required this.followingId,
  });
}

class UnfollowUser extends UseCase<void, UnfollowUserParams> {
  final SocialRepository repository;

  UnfollowUser(this.repository);

  @override
  Future<Either<Failure, void>> call(UnfollowUserParams params) async {
    return await repository.unfollowUser(params.followerId, params.followingId);
  }
}
