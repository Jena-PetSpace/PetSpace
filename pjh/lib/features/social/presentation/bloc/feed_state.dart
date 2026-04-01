part of 'feed_bloc.dart';

abstract class FeedState extends Equatable {
  const FeedState();

  @override
  List<Object?> get props => [];
}

class FeedInitial extends FeedState {}

class FeedLoading extends FeedState {}

class FeedLoaded extends FeedState {
  final List<Post> posts;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? error;

  const FeedLoaded({
    required this.posts,
    required this.hasReachedMax,
    this.isLoadingMore = false,
    this.error,
  });

  FeedLoaded copyWith({
    List<Post>? posts,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? error,
  }) {
    return FeedLoaded(
      posts: posts ?? this.posts,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [posts, hasReachedMax, isLoadingMore, error];
}

class FeedCreatingPost extends FeedState {}

class FeedPostCreated extends FeedState {
  final Post post;

  const FeedPostCreated(this.post);

  @override
  List<Object?> get props => [post];
}

class FeedPostUpdated extends FeedState {
  final Post post;

  const FeedPostUpdated(this.post);

  @override
  List<Object?> get props => [post];
}

class FeedError extends FeedState {
  final String message;
  final bool isNetworkError;

  const FeedError(this.message, {this.isNetworkError = false});

  @override
  List<Object?> get props => [message, isNetworkError];
}

class FeedSavedPostsLoaded extends FeedState {
  final List<Post> savedPosts;
  const FeedSavedPostsLoaded(this.savedPosts);

  @override
  List<Object?> get props => [savedPosts];
}

class FeedPostSaved extends FeedState {
  final String postId;
  const FeedPostSaved(this.postId);

  @override
  List<Object?> get props => [postId];
}

class FeedPostUnsaved extends FeedState {
  final String postId;
  const FeedPostUnsaved(this.postId);

  @override
  List<Object?> get props => [postId];
}
