part of 'bookmark_bloc.dart';

abstract class BookmarkEvent extends Equatable {
  const BookmarkEvent();

  @override
  List<Object?> get props => [];
}

class LoadBookmarkCollections extends BookmarkEvent {
  final String userId;
  const LoadBookmarkCollections({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class CreateBookmarkCollection extends BookmarkEvent {
  final String userId;
  final String name;
  final String emoji;

  const CreateBookmarkCollection({
    required this.userId,
    required this.name,
    this.emoji = '📁',
  });

  @override
  List<Object?> get props => [userId, name, emoji];
}

class DeleteBookmarkCollection extends BookmarkEvent {
  final String collectionId;
  const DeleteBookmarkCollection({required this.collectionId});

  @override
  List<Object?> get props => [collectionId];
}

class LoadSavedPostsByCollection extends BookmarkEvent {
  final String userId;
  final String? collectionId;

  const LoadSavedPostsByCollection({
    required this.userId,
    this.collectionId,
  });

  @override
  List<Object?> get props => [userId, collectionId];
}

class MovePostToCollection extends BookmarkEvent {
  final String postId;
  final String userId;
  final String? collectionId;

  const MovePostToCollection({
    required this.postId,
    required this.userId,
    this.collectionId,
  });

  @override
  List<Object?> get props => [postId, userId, collectionId];
}
