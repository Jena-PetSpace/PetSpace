part of 'feed_bloc.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadFeedRequested extends FeedEvent {
  final String? userId;
  final int limit;

  const LoadFeedRequested({
    this.userId,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [userId, limit];
}

class RefreshFeedRequested extends FeedEvent {
  final String? userId;

  const RefreshFeedRequested({this.userId});

  @override
  List<Object?> get props => [userId];
}

class LoadMorePostsRequested extends FeedEvent {
  final String? userId;

  const LoadMorePostsRequested({this.userId});

  @override
  List<Object?> get props => [userId];
}

class CreatePostRequested extends FeedEvent {
  final Post post;

  const CreatePostRequested({required this.post});

  @override
  List<Object?> get props => [post];
}

class LikePostRequested extends FeedEvent {
  final String postId;
  final String userId;

  const LikePostRequested({
    required this.postId,
    required this.userId,
  });

  @override
  List<Object?> get props => [postId, userId];
}

class UnlikePostRequested extends FeedEvent {
  final String postId;
  final String userId;

  const UnlikePostRequested({
    required this.postId,
    required this.userId,
  });

  @override
  List<Object?> get props => [postId, userId];
}

class UpdatePostRequested extends FeedEvent {
  final Post post;

  const UpdatePostRequested({required this.post});

  @override
  List<Object?> get props => [post];
}

class DeletePostRequested extends FeedEvent {
  final String postId;

  const DeletePostRequested({required this.postId});

  @override
  List<Object?> get props => [postId];
}