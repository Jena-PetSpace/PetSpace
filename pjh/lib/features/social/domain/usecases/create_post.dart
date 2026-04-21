import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/post.dart';
import '../repositories/social_repository.dart';

class CreatePostParams {
  final Post post;
  final List<File> images;

  const CreatePostParams({required this.post, this.images = const []});
}

class CreatePost extends UseCase<Post, CreatePostParams> {
  final SocialRepository repository;

  CreatePost(this.repository);

  @override
  Future<Either<Failure, Post>> call(CreatePostParams params) async {
    return await repository.createPost(params.post, images: params.images);

  }
}
