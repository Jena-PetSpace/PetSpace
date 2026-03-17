import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/social_repository.dart';

class SavePost implements UseCase<void, SavePostParams> {
  final SocialRepository repository;
  SavePost(this.repository);

  @override
  Future<Either<Failure, void>> call(SavePostParams params) =>
      repository.savePost(params.postId, params.userId);
}

class SavePostParams extends Equatable {
  final String postId;
  final String userId;
  const SavePostParams({required this.postId, required this.userId});

  @override
  List<Object?> get props => [postId, userId];
}
