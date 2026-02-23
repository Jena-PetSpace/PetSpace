import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class DeleteCommentParams {
  final String commentId;

  const DeleteCommentParams({required this.commentId});
}

class DeleteComment extends UseCase<void, DeleteCommentParams> {
  final SocialRepository repository;

  DeleteComment(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteCommentParams params) async {
    return await repository.deleteComment(params.commentId);
  }
}
