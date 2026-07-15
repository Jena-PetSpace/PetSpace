part of 'bookmark_bloc.dart';

enum BookmarkLoadStatus { initial, loading, success, failure }

enum BookmarkActionStatus { idle, loading, success, failure }

class BookmarkState extends Equatable {
  final BookmarkLoadStatus collectionsStatus;
  final BookmarkLoadStatus allCountStatus;
  final BookmarkLoadStatus unassignedCountStatus;
  final BookmarkActionStatus actionStatus;
  final List<BookmarkCollection> collections;
  final int? allCount;
  final int? unassignedCount;
  final String? collectionsError;
  final String? allCountError;
  final String? unassignedCountError;
  final String? actionError;

  const BookmarkState({
    this.collectionsStatus = BookmarkLoadStatus.initial,
    this.allCountStatus = BookmarkLoadStatus.initial,
    this.unassignedCountStatus = BookmarkLoadStatus.initial,
    this.actionStatus = BookmarkActionStatus.idle,
    this.collections = const [],
    this.allCount,
    this.unassignedCount,
    this.collectionsError,
    this.allCountError,
    this.unassignedCountError,
    this.actionError,
  });

  BookmarkState copyWith({
    BookmarkLoadStatus? collectionsStatus,
    BookmarkLoadStatus? allCountStatus,
    BookmarkLoadStatus? unassignedCountStatus,
    BookmarkActionStatus? actionStatus,
    List<BookmarkCollection>? collections,
    int? allCount,
    int? unassignedCount,
    String? collectionsError,
    String? allCountError,
    String? unassignedCountError,
    String? actionError,
    bool clearCollectionsError = false,
    bool clearAllCountError = false,
    bool clearUnassignedCountError = false,
    bool clearActionError = false,
  }) {
    return BookmarkState(
      collectionsStatus: collectionsStatus ?? this.collectionsStatus,
      allCountStatus: allCountStatus ?? this.allCountStatus,
      unassignedCountStatus:
          unassignedCountStatus ?? this.unassignedCountStatus,
      actionStatus: actionStatus ?? this.actionStatus,
      collections: collections ?? this.collections,
      allCount: allCount ?? this.allCount,
      unassignedCount: unassignedCount ?? this.unassignedCount,
      collectionsError: clearCollectionsError
          ? null
          : collectionsError ?? this.collectionsError,
      allCountError:
          clearAllCountError ? null : allCountError ?? this.allCountError,
      unassignedCountError: clearUnassignedCountError
          ? null
          : unassignedCountError ?? this.unassignedCountError,
      actionError: clearActionError ? null : actionError ?? this.actionError,
    );
  }

  @override
  List<Object?> get props => [
        collectionsStatus,
        allCountStatus,
        unassignedCountStatus,
        actionStatus,
        collections,
        allCount,
        unassignedCount,
        collectionsError,
        allCountError,
        unassignedCountError,
        actionError,
      ];
}
