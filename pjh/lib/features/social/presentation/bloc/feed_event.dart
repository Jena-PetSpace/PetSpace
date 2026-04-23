part of 'feed_bloc.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

class LoadFeedRequested extends FeedEvent {
  final String? userId;
  final int limit;
  final bool followingOnly;

  const LoadFeedRequested({
    this.userId,
    this.limit = 20,
    this.followingOnly = false,
  });

  @override
  List<Object?> get props => [userId, limit, followingOnly];
}

class RefreshFeedRequested extends FeedEvent {
  final String? userId;
  final bool followingOnly;

  const RefreshFeedRequested({this.userId, this.followingOnly = false});

  @override
  List<Object?> get props => [userId, followingOnly];
}

class LoadMorePostsRequested extends FeedEvent {
  final String? userId;
  final bool followingOnly;

  const LoadMorePostsRequested({this.userId, this.followingOnly = false});

  @override
  List<Object?> get props => [userId, followingOnly];
}

class CreatePostRequested extends FeedEvent {
  final Post post;
  final List<File> images;

  const CreatePostRequested({required this.post, this.images = const []});

  @override
  List<Object?> get props => [post, images];
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

class SavePostRequested extends FeedEvent {
  final String postId;
  final String userId;
  const SavePostRequested({required this.postId, required this.userId});

  @override
  List<Object?> get props => [postId, userId];
}

class UnsavePostRequested extends FeedEvent {
  final String postId;
  final String userId;
  const UnsavePostRequested({required this.postId, required this.userId});

  @override
  List<Object?> get props => [postId, userId];
}

class LoadSavedPostsRequested extends FeedEvent {
  final String userId;
  const LoadSavedPostsRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class LoadRecommendedPostsRequested extends FeedEvent {
  final String userId;
  final int limit;
  final int offset;

  const LoadRecommendedPostsRequested({
    required this.userId,
    this.limit = 20,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [userId, limit, offset];
}

class SubscribeToFeedRealtime extends FeedEvent {
  final String userId;
  const SubscribeToFeedRealtime({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class RealtimeLikeReceived extends FeedEvent {
  final Map<String, dynamic> data;
  const RealtimeLikeReceived(this.data);

  @override
  List<Object?> get props => [data];
}

class RealtimeCommentReceived extends FeedEvent {
  final Map<String, dynamic> data;
  const RealtimeCommentReceived(this.data);

  @override
  List<Object?> get props => [data];
}
