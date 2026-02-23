import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';

part 'social_event.dart';
part 'social_state.dart';

class SocialBloc extends Bloc<SocialEvent, SocialState> {
  final SocialRepository socialRepository;

  SocialBloc({
    required this.socialRepository,
  }) : super(SocialInitial()) {
    on<LoadUserFeedRequested>(_onLoadUserFeedRequested);
    on<LoadExplorePostsRequested>(_onLoadExplorePostsRequested);
    on<CreatePostRequested>(_onCreatePostRequested);
    on<LikePostRequested>(_onLikePostRequested);
    on<UnlikePostRequested>(_onUnlikePostRequested);
    on<DeletePostRequested>(_onDeletePostRequested);
    on<FollowUserRequested>(_onFollowUserRequested);
    on<UnfollowUserRequested>(_onUnfollowUserRequested);
    on<RefreshFeedRequested>(_onRefreshFeedRequested);
    on<LoadMorePostsRequested>(_onLoadMorePostsRequested);
  }

  Future<void> _onLoadUserFeedRequested(
    LoadUserFeedRequested event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());

    final result = await socialRepository.getFeedPosts(
      userId: event.userId,
      limit: event.limit,
    );

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (posts) => emit(SocialLoaded(
        posts: posts,
        hasReachedMax: posts.length < event.limit,
      )),
    );
  }

  Future<void> _onLoadExplorePostsRequested(
    LoadExplorePostsRequested event,
    Emitter<SocialState> emit,
  ) async {
    emit(SocialLoading());

    final result = await socialRepository.getExplorePosts(
      limit: event.limit,
    );

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (posts) => emit(SocialLoaded(
        posts: posts,
        hasReachedMax: posts.length < event.limit,
      )),
    );
  }

  Future<void> _onCreatePostRequested(
    CreatePostRequested event,
    Emitter<SocialState> emit,
  ) async {
    final result = await socialRepository.createPost(event.post);

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (_) => add(RefreshFeedRequested(userId: event.post.authorId)),
    );
  }

  Future<void> _onLikePostRequested(
    LikePostRequested event,
    Emitter<SocialState> emit,
  ) async {
    final result = await socialRepository.likePost(event.postId, event.userId);

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (_) {
        // Update the current state optimistically
        if (state is SocialLoaded) {
          final currentState = state as SocialLoaded;
          final updatedPosts = currentState.posts.map((post) {
            if (post.id == event.postId) {
              return post.copyWith(
                likesCount: post.likesCount + 1,
                isLikedByCurrentUser: true,
              );
            }
            return post;
          }).toList();

          emit(currentState.copyWith(posts: updatedPosts));
        }
      },
    );
  }

  Future<void> _onUnlikePostRequested(
    UnlikePostRequested event,
    Emitter<SocialState> emit,
  ) async {
    final result = await socialRepository.unlikePost(event.postId, event.userId);

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (_) {
        // Update the current state optimistically
        if (state is SocialLoaded) {
          final currentState = state as SocialLoaded;
          final updatedPosts = currentState.posts.map((post) {
            if (post.id == event.postId) {
              return post.copyWith(
                likesCount: post.likesCount - 1,
                isLikedByCurrentUser: false,
              );
            }
            return post;
          }).toList();

          emit(currentState.copyWith(posts: updatedPosts));
        }
      },
    );
  }

  Future<void> _onDeletePostRequested(
    DeletePostRequested event,
    Emitter<SocialState> emit,
  ) async {
    final result = await socialRepository.deletePost(event.postId);

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (_) {
        // Remove post from current state
        if (state is SocialLoaded) {
          final currentState = state as SocialLoaded;
          final updatedPosts = currentState.posts
              .where((post) => post.id != event.postId)
              .toList();

          emit(currentState.copyWith(posts: updatedPosts));
        }
      },
    );
  }

  Future<void> _onFollowUserRequested(
    FollowUserRequested event,
    Emitter<SocialState> emit,
  ) async {
    final result = await socialRepository.followUser(event.followerId, event.followingId);

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (_) {}, // Success handled
    );
  }

  Future<void> _onUnfollowUserRequested(
    UnfollowUserRequested event,
    Emitter<SocialState> emit,
  ) async {
    final result = await socialRepository.unfollowUser(event.followerId, event.followingId);

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (_) {}, // Success handled
    );
  }

  Future<void> _onRefreshFeedRequested(
    RefreshFeedRequested event,
    Emitter<SocialState> emit,
  ) async {
    final result = await socialRepository.getFeedPosts(
      userId: event.userId,
      limit: 20,
    );

    result.fold(
      (failure) => emit(SocialError(failure.message)),
      (posts) => emit(SocialLoaded(
        posts: posts,
        hasReachedMax: posts.length < 20,
      )),
    );
  }

  Future<void> _onLoadMorePostsRequested(
    LoadMorePostsRequested event,
    Emitter<SocialState> emit,
  ) async {
    if (state is SocialLoaded) {
      final currentState = state as SocialLoaded;
      if (currentState.hasReachedMax || currentState.isLoadingMore) return;

      emit(currentState.copyWith(isLoadingMore: true));

      final result = await socialRepository.getFeedPosts(
        userId: event.userId,
        limit: 20,
        lastPostId: currentState.posts.isNotEmpty ? currentState.posts.last.id : null,
      );

      result.fold(
        (failure) => emit(currentState.copyWith(
          isLoadingMore: false,
          error: failure.message,
        )),
        (morePosts) => emit(SocialLoaded(
          posts: [...currentState.posts, ...morePosts],
          hasReachedMax: morePosts.length < 20,
          isLoadingMore: false,
        )),
      );
    }
  }
}