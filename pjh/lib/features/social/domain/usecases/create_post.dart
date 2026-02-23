import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/post.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class CreatePostParams {
  final Post post;

  const CreatePostParams({required this.post});
}

class CreatePost extends UseCase<Post, CreatePostParams> {
  final SocialRepository repository;

  CreatePost(this.repository);

  @override
  Future<Either<Failure, Post>> call(CreatePostParams params) async {
    return await repository.createPost(params.post);
  }
}