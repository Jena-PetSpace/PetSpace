part of 'bookmark_bloc.dart';

abstract class BookmarkState extends Equatable {
  const BookmarkState();

  @override
  List<Object?> get props => [];
}

class BookmarkInitial extends BookmarkState {}

class BookmarkLoading extends BookmarkState {}

class BookmarkPostsLoading extends BookmarkState {}

class BookmarkCollectionsLoaded extends BookmarkState {
  final List<BookmarkCollection> collections;
  const BookmarkCollectionsLoaded(this.collections);

  @override
  List<Object?> get props => [collections];
}

class BookmarkPostsLoaded extends BookmarkState {
  final String? collectionId;
  final List<Post> posts;

  const BookmarkPostsLoaded({
    this.collectionId,
    required this.posts,
  });

  @override
  List<Object?> get props => [collectionId, posts];
}

class BookmarkPostMoved extends BookmarkState {
  final String postId;
  final String? collectionId;

  const BookmarkPostMoved({required this.postId, this.collectionId});

  @override
  List<Object?> get props => [postId, collectionId];
}

class BookmarkError extends BookmarkState {
  final String message;
  const BookmarkError(this.message);

  @override
  List<Object?> get props => [message];
}
