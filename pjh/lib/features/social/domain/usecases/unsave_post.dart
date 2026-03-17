import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/social_repository.dart';

class UnsavePost implements UseCase<void, UnsavePostParams> {
  final SocialRepository repository;
  UnsavePost(this.repository);

  @override
  Future<Either<Failure, void>> call(UnsavePostParams params) =>
      repository.unsavePost(params.postId, params.userId);
}

class UnsavePostParams extends Equatable {
  final String postId;
  final String userId;
  const UnsavePostParams({required this.postId, required this.userId});

  @override
  List<Object?> get props => [postId, userId];
}
