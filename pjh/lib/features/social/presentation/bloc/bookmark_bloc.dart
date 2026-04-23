import 'dart:developer' as dev;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/bookmark_collection.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';

part 'bookmark_event.dart';
part 'bookmark_state.dart';

class BookmarkBloc extends Bloc<BookmarkEvent, BookmarkState> {
  final SocialRepository _repository;

  BookmarkBloc({required SocialRepository repository})
      : _repository = repository,
        super(BookmarkInitial()) {
    on<LoadBookmarkCollections>(_onLoadCollections);
    on<CreateBookmarkCollection>(_onCreateCollection);
    on<DeleteBookmarkCollection>(_onDeleteCollection);
    on<LoadSavedPostsByCollection>(_onLoadSavedPosts);
    on<MovePostToCollection>(_onMovePostToCollection);
  }

  Future<void> _onLoadCollections(
    LoadBookmarkCollections event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(BookmarkLoading());
    final result = await _repository.getBookmarkCollections(event.userId);
    result.fold(
      (failure) => emit(BookmarkError(failure.message)),
      (collections) => emit(BookmarkCollectionsLoaded(collections)),
    );
  }

  Future<void> _onCreateCollection(
    CreateBookmarkCollection event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _repository.createBookmarkCollection(
      userId: event.userId,
      name: event.name,
      emoji: event.emoji,
    );
    result.fold(
      (failure) => emit(BookmarkError(failure.message)),
      (collection) {
        if (state is BookmarkCollectionsLoaded) {
          final current = (state as BookmarkCollectionsLoaded).collections;
          emit(BookmarkCollectionsLoaded([collection, ...current]));
        } else {
          emit(BookmarkCollectionsLoaded([collection]));
        }
      },
    );
  }

  Future<void> _onDeleteCollection(
    DeleteBookmarkCollection event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _repository.deleteBookmarkCollection(event.collectionId);
    result.fold(
      (failure) => emit(BookmarkError(failure.message)),
      (_) {
        if (state is BookmarkCollectionsLoaded) {
          final current = (state as BookmarkCollectionsLoaded).collections;
          emit(BookmarkCollectionsLoaded(
              current.where((c) => c.id != event.collectionId).toList()));
        }
      },
    );
  }

  Future<void> _onLoadSavedPosts(
    LoadSavedPostsByCollection event,
    Emitter<BookmarkState> emit,
  ) async {
    emit(BookmarkPostsLoading());
    final result = await _repository.getSavedPosts(
        userId: event.userId, limit: 50);
    result.fold(
      (failure) => emit(BookmarkError(failure.message)),
      (posts) => emit(BookmarkPostsLoaded(
          collectionId: event.collectionId, posts: posts)),
    );
  }

  Future<void> _onMovePostToCollection(
    MovePostToCollection event,
    Emitter<BookmarkState> emit,
  ) async {
    final result = await _repository.updateSavedPostCollection(
      postId: event.postId,
      userId: event.userId,
      collectionId: event.collectionId,
    );
    result.fold(
      (failure) {
        dev.log('MovePostToCollection failed: ${failure.message}', name: 'BookmarkBloc');
        emit(BookmarkError(failure.message));
      },
      (_) => emit(BookmarkPostMoved(
          postId: event.postId, collectionId: event.collectionId)),
    );
  }
}
