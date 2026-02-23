part of 'social_bloc.dart';

abstract class SocialEvent extends Equatable {
  const SocialEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserFeedRequested extends SocialEvent {
  final String userId;
  final int limit;

  const LoadUserFeedRequested({
    required this.userId,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [userId, limit];
}

class LoadExplorePostsRequested extends SocialEvent {
  final int limit;

  const LoadExplorePostsRequested({
    this.limit = 20,
  });

  @override
  List<Object?> get props => [limit];
}

class CreatePostRequested extends SocialEvent {
  final Post post;
  final List<File> images;

  const CreatePostRequested({
    required this.post,
    this.images = const [],
  });

  @override
  List<Object?> get props => [post, images];
}

class LikePostRequested extends SocialEvent {
  final String postId;
  final String userId;

  const LikePostRequested({
    required this.postId,
    required this.userId,
  });

  @override
  List<Object?> get props => [postId, userId];
}

class UnlikePostRequested extends SocialEvent {
  final String postId;
  final String userId;

  const UnlikePostRequested({
    required this.postId,
    required this.userId,
  });

  @override
  List<Object?> get props => [postId, userId];
}

class DeletePostRequested extends SocialEvent {
  final String postId;

  const DeletePostRequested({required this.postId});

  @override
  List<Object?> get props => [postId];
}

class FollowUserRequested extends SocialEvent {
  final String followerId;
  final String followingId;

  const FollowUserRequested({
    required this.followerId,
    required this.followingId,
  });

  @override
  List<Object?> get props => [followerId, followingId];
}

class UnfollowUserRequested extends SocialEvent {
  final String followerId;
  final String followingId;

  const UnfollowUserRequested({
    required this.followerId,
    required this.followingId,
  });

  @override
  List<Object?> get props => [followerId, followingId];
}

class RefreshFeedRequested extends SocialEvent {
  final String userId;

  const RefreshFeedRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class LoadMorePostsRequested extends SocialEvent {
  final String userId;

  const LoadMorePostsRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}