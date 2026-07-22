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

  const CreateBookmarkCollection({
    required this.userId,
    required this.name,
  });

  @override
  List<Object?> get props => [userId, name];
}

class DeleteBookmarkCollection extends BookmarkEvent {
  final String collectionId;
  final String userId;

  const DeleteBookmarkCollection({
    required this.collectionId,
    required this.userId,
  });

  @override
  List<Object?> get props => [collectionId, userId];
}
