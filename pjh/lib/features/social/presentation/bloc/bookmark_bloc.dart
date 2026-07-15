import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/bookmark_collection.dart';
import '../../domain/entities/saved_posts_page.dart';
import '../../domain/repositories/social_repository.dart';

part 'bookmark_event.dart';
part 'bookmark_state.dart';

class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  final SocialRepository _repository;
  int _loadGeneration = 0;

  BookmarkBloc({required SocialRepository repository})
      : _repository = repository,
        super(const BookmarkState()) {
    on<LoadBookmarkCollections>(_onLoadSummary);
    on<CreateBookmarkCollection>(_onCreateCollection);
    on<DeleteBookmarkCollection>(_onDeleteCollection);
  }

  Future<void> _onLoadSummary(
    LoadBookmarkCollections event,
    Emitter<BookmarkState> emit,
  ) async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(
      collectionsStatus: BookmarkLoadStatus.loading,
      allCountStatus: BookmarkLoadStatus.loading,
      unassignedCountStatus: BookmarkLoadStatus.loading,
      actionStatus: BookmarkActionStatus.idle,
      clearCollectionsError: true,
      clearAllCountError: true,
      clearUnassignedCountError: true,
      clearActionError: true,
    ));

    final collectionsFuture = _repository.getBookmarkCollections(event.userId);
    final allCountFuture = _repository.countSavedPosts(
      userId: event.userId,
      scope: const SavedPostsScope.all(),
    );
    final unassignedCountFuture = _repository.countSavedPosts(
      userId: event.userId,
      scope: const SavedPostsScope.unassigned(),
    );
    final collectionsResult = await collectionsFuture;
    final allCountResult = await allCountFuture;
    final unassignedCountResult = await unassignedCountFuture;
    if (generation != _loadGeneration || emit.isDone) return;

    var next = state;
    collectionsResult.fold(
      (failure) => next = next.copyWith(
        collectionsStatus: BookmarkLoadStatus.failure,
        collectionsError: failure.message,
      ),
      (collections) => next = next.copyWith(
        collectionsStatus: BookmarkLoadStatus.success,
        collections: collections,
        clearCollectionsError: true,
      ),
    );
    allCountResult.fold(
      (failure) => next = next.copyWith(
        allCountStatus: BookmarkLoadStatus.failure,
        allCountError: failure.message,
      ),
      (count) => next = next.copyWith(
        allCountStatus: BookmarkLoadStatus.success,
        allCount: count,
        clearAllCountError: true,
      ),
    );
    unassignedCountResult.fold(
      (failure) => next = next.copyWith(
        unassignedCountStatus: BookmarkLoadStatus.failure,
        unassignedCountError: failure.message,
      ),
      (count) => next = next.copyWith(
        unassignedCountStatus: BookmarkLoadStatus.success,
        unassignedCount: count,
        clearUnassignedCountError: true,
      ),
    );
    emit(next);
  }

  Future<void> _onCreateCollection(
    CreateBookmarkCollection event,
    Emitter<BookmarkState> emit,
  ) async {
    final name = event.name.trim();
    if (name.isEmpty) {
      emit(state.copyWith(
        actionStatus: BookmarkActionStatus.failure,
        actionError: '컬렉션 이름을 입력해주세요.',
      ));
      return;
    }
    emit(state.copyWith(
      actionStatus: BookmarkActionStatus.loading,
      clearActionError: true,
    ));
    final result = await _repository.createBookmarkCollection(
      userId: event.userId,
      name: name,
    );
    result.fold(
      (failure) => emit(state.copyWith(
        actionStatus: BookmarkActionStatus.failure,
        actionError: failure.message,
      )),
      (collection) => emit(state.copyWith(
        actionStatus: BookmarkActionStatus.success,
        collectionsStatus: BookmarkLoadStatus.success,
        collections: [collection, ...state.collections],
        clearActionError: true,
      )),
    );
  }

  Future<void> _onDeleteCollection(
    DeleteBookmarkCollection event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(state.copyWith(
      actionStatus: BookmarkActionStatus.loading,
      clearActionError: true,
    ));
    final result = await _repository.deleteBookmarkCollection(
      collectionId: event.collectionId,
      userId: event.userId,
    );
    await result.fold(
      (failure) async => emit(state.copyWith(
        actionStatus: BookmarkActionStatus.failure,
        actionError: failure.message,
      )),
      (_) async {
        final allCountFuture = _repository.countSavedPosts(
          userId: event.userId,
          scope: const SavedPostsScope.all(),
        );
        final unassignedCountFuture = _repository.countSavedPosts(
          userId: event.userId,
          scope: const SavedPostsScope.unassigned(),
        );
        final allCountResult = await allCountFuture;
        final unassignedCountResult = await unassignedCountFuture;
        var next = state.copyWith(
          actionStatus: BookmarkActionStatus.success,
          collections: state.collections
              .where((item) => item.id != event.collectionId)
              .toList(),
          clearActionError: true,
        );
        allCountResult.fold(
          (failure) => next = next.copyWith(
            allCountStatus: BookmarkLoadStatus.failure,
            allCountError: failure.message,
          ),
          (count) => next = next.copyWith(
            allCountStatus: BookmarkLoadStatus.success,
            allCount: count,
            clearAllCountError: true,
          ),
        );
        unassignedCountResult.fold(
          (failure) => next = next.copyWith(
            unassignedCountStatus: BookmarkLoadStatus.failure,
            unassignedCountError: failure.message,
          ),
          (count) => next = next.copyWith(
            unassignedCountStatus: BookmarkLoadStatus.success,
            unassignedCount: count,
            clearUnassignedCountError: true,
          ),
        );
        emit(next);
      },
    );
  }
}
