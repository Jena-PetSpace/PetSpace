import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/comment.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class CreateCommentParams {
  final Comment comment;

  const CreateCommentParams({required this.comment});
}

class CreateComment extends UseCase<Comment, CreateCommentParams> {
  final SocialRepository repository;

  CreateComment(this.repository);

  @override
  Future<Either<Failure, Comment>> call(CreateCommentParams params) async {
    return await repository.createComment(params.comment);
  }
}