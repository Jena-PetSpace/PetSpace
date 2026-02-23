import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/post.dart';
import '../repositories/social_repository.dart';

class UpdatePostParams {
  final Post post;

  const UpdatePostParams({required this.post});
}

class UpdatePost extends UseCase<Post, UpdatePostParams> {
  final SocialRepository repository;

  UpdatePost(this.repository);

  @override
  Future<Either<Failure, Post>> call(UpdatePostParams params) async {
    return await repository.updatePost(params.post);
  }
}
