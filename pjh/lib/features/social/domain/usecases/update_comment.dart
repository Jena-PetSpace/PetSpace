import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/comment.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class UpdateCommentParams {
  final Comment comment;

  const UpdateCommentParams({required this.comment});
}

class UpdateComment extends UseCase<Comment, UpdateCommentParams> {
  final SocialRepository repository;

  UpdateComment(this.repository);

  @override
  Future<Either<Failure, Comment>> call(UpdateCommentParams params) async {
    return await repository.updateComment(params.comment);
  }
}
