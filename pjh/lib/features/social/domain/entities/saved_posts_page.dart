import 'package:equatable/equatable.dart';

import 'post.dart';

enum SavedPostsScopeType { all, unassigned, collection }

class SavedPostsScope extends Equatable {
  final SavedPostsScopeType type;
  final String? collectionId;

  const SavedPostsScope._(this.type, this.collectionId);

  const SavedPostsScope.all() : this._(SavedPostsScopeType.all, null);
  const SavedPostsScope.unassigned()
      : this._(SavedPostsScopeType.unassigned, null);
  const SavedPostsScope.collection(String collectionId)
      : this._(SavedPostsScopeType.collection, collectionId);

  @override
  List<Object?> get props => [type, collectionId];
}

class SavedPostsCursor extends Equatable {
  final DateTime savedAt;
  final String savedPostId;

  const SavedPostsCursor({
    required this.savedAt,
    required this.savedPostId,
  });

  @override
  List<Object?> get props => [savedAt, savedPostId];
}

class SavedPostLocation extends Equatable {
  final String savedPostId;
  final String? collectionId;

  const SavedPostLocation({
    required this.savedPostId,
    this.collectionId,
  });

  @override
  List<Object?> get props => [savedPostId, collectionId];
}

class SavedPostItem extends Equatable {
  final String savedPostId;
  final String? collectionId;
  final DateTime savedAt;
  final Post post;

  const SavedPostItem({
    required this.savedPostId,
    this.collectionId,
    required this.savedAt,
    required this.post,
  });

  @override
  List<Object?> get props => [savedPostId, collectionId, savedAt, post];
}

class SavedPostsPage extends Equatable {
  final List<SavedPostItem> items;
  final bool hasMore;
  final SavedPostsCursor? nextCursor;

  const SavedPostsPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  @override
  List<Object?> get props => [items, hasMore, nextCursor];
}
