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

  const FeedError(this.message);

  @override
  List<Object?> get props => [message];
}