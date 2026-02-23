import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/social_user.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class GetUserProfileParams {
  final String userId;

  const GetUserProfileParams({required this.userId});
}

class GetUserProfile extends UseCase<SocialUser, GetUserProfileParams> {
  final SocialRepository repository;

  GetUserProfile(this.repository);

  @override
  Future<Either<Failure, SocialUser>> call(GetUserProfileParams params) async {
    return await repository.getUserProfile(params.userId);
  }
}