import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/post.dart';
import '../repositories/social_repository.dart';

class GetSavedPosts implements UseCase<List<Post>, GetSavedPostsParams> {
  final SocialRepository repository;
  GetSavedPosts(this.repository);

  @override
  Future<Either<Failure, List<Post>>> call(GetSavedPostsParams params) =>
      repository.getSavedPosts(userId: params.userId, limit: params.limit);
}

class GetSavedPostsParams extends Equatable {
  final String userId;
  final int limit;
  const GetSavedPostsParams({required this.userId, this.limit = 20});

  @override
  List<Object?> get props => [userId, limit];
}
