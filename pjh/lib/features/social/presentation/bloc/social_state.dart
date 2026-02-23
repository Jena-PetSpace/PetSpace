part of 'social_bloc.dart';

abstract class SocialState extends Equatable {
  const SocialState();

  @override
  List<Object?> get props => [];
}

class SocialInitial extends SocialState {}

class SocialLoading extends SocialState {}

class SocialLoaded extends SocialState {
  final List<Post> posts;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? error;

  const SocialLoaded({
    required this.posts,
    required this.hasReachedMax,
    this.isLoadingMore = false,
    this.error,
  });

  SocialLoaded copyWith({
    List<Post>? posts,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? error,
  }) {
    return SocialLoaded(
      posts: posts ?? this.posts,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [posts, hasReachedMax, isLoadingMore, error];
}

class SocialError extends SocialState {
  final String message;

  const SocialError(this.message);

  @override
  List<Object?> get props => [message];
}

class SocialPostCreated extends SocialState {
  final Post post;

  const SocialPostCreated(this.post);

  @override
  List<Object?> get props => [post];
}