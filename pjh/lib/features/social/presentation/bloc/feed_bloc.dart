import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/analytics_service.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post.dart';
import '../../domain/usecases/delete_post.dart';
import '../../domain/usecases/get_feed.dart';
import '../../domain/usecases/like_post.dart';
import '../../domain/usecases/unlike_post.dart';
import '../../domain/usecases/save_post.dart';
import '../../../../core/services/realtime_service.dart';
import '../../domain/usecases/unsave_post.dart';
import '../../domain/usecases/get_saved_posts.dart';
import '../../domain/usecases/update_post.dart';
import '../../domain/repositories/social_repository.dart';
import '../controllers/post_interaction_coordinator.dart';

part 'feed_event.dart';
part 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final GetFeed _getFeed;
  final CreatePost _createPost;
  final UpdatePost _updatePost;
  final DeletePost _deletePost;
  final LikePost _likePost;
  final UnlikePost _unlikePost;
  final SavePost _savePost;
  final UnsavePost _unsavePost;
  final GetSavedPosts _getSavedPosts;
  final SocialRepository _socialRepository;
  final RealtimeService _realtimeService;
  StreamSubscription<Map<String, dynamic>>? _likeSub;
  StreamSubscription<Map<String, dynamic>>? _commentSub;
  final PostInteractionCoordinator _interactionCoordinator;

  FeedBloc({
    required GetFeed getFeed,
    required CreatePost createPost,
    required UpdatePost updatePost,
    required DeletePost deletePost,
    required LikePost likePost,
    required UnlikePost unlikePost,
    required SavePost savePost,
    required UnsavePost unsavePost,
    required GetSavedPosts getSavedPosts,
    required SocialRepository socialRepository,
    PostInteractionCoordinator? interactionCoordinator,
    RealtimeService? realtimeService,
  })  : _getFeed = getFeed,
        _createPost = createPost,
        _updatePost = updatePost,
        _deletePost = deletePost,
        _likePost = likePost,
        _unlikePost = unlikePost,
        _savePost = savePost,
        _unsavePost = unsavePost,
        _getSavedPosts = getSavedPosts,
        _socialRepository = socialRepository,
        _interactionCoordinator = interactionCoordinator ??
            PostInteractionCoordinator(repository: socialRepository),
        _realtimeService = realtimeService ?? RealtimeService(),
        super(FeedInitial()) {
    on<LoadFeedRequested>(_onLoadFeedRequested);
    on<RefreshFeedRequested>(_onRefreshFeedRequested);
    on<LoadMorePostsRequested>(_onLoadMorePostsRequested);
    on<LoadRecommendedPostsRequested>(_onLoadRecommendedPostsRequested);
    on<CreatePostRequested>(_onCreatePostRequested);
    on<UpdatePostRequested>(_onUpdatePostRequested);
    on<DeletePostRequested>(_onDeletePostRequested);
    on<LikePostRequested>(_onLikePostRequested);
    on<UnlikePostRequested>(_onUnlikePostRequested);
    on<SavePostRequested>(_onSavePostRequested);
    on<UnsavePostRequested>(_onUnsavePostRequested);
    on<LoadSavedPostsRequested>(_onLoadSavedPostsRequested);
    on<RealtimeLikeReceived>(_onRealtimeLikeReceived);
    on<RealtimeCommentReceived>(_onRealtimeCommentReceived);
  }

  Future<void> _onLoadFeedRequested(
    LoadFeedRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(FeedLoading());

    final result = await _getFeed(
      GetFeedParams(
        userId: event.userId,
        limit: event.limit,
        followingOnly: event.followingOnly,
      ),
    );

    result.fold(
      (failure) => emit(
        FeedError(failure.message, isNetworkError: failure is NetworkFailure),
      ),
      (posts) => emit(
        FeedLoaded(posts: posts, hasReachedMax: posts.length < event.limit),
      ),
    );
  }

  Future<void> _onRefreshFeedRequested(
    RefreshFeedRequested event,
    Emitter<FeedState> emit,
  ) async {
    final result = await _getFeed(
      GetFeedParams(
        userId: event.userId,
        limit: 20,
        followingOnly: event.followingOnly,
      ),
    );

    result.fold(
      (failure) => emit(
        FeedError(failure.message, isNetworkError: failure is NetworkFailure),
      ),
      (posts) =>
          emit(FeedLoaded(posts: posts, hasReachedMax: posts.length < 20)),
    );
  }

  Future<void> _onLoadMorePostsRequested(
    LoadMorePostsRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (state is FeedLoaded) {
      final currentState = state as FeedLoaded;
      if (currentState.hasReachedMax) return;

      emit(currentState.copyWith(isLoadingMore: true));

      final result = await _getFeed(
        GetFeedParams(
          userId: event.userId,
          limit: 20,
          lastPostId:
              currentState.posts.isNotEmpty ? currentState.posts.last.id : null,
          lastCreatedAt: currentState.posts.isNotEmpty
              ? currentState.posts.last.createdAt
              : null,
          followingOnly: event.followingOnly,
        ),
      );

      result.fold(
        (failure) => emit(
          currentState.copyWith(isLoadingMore: false, error: failure.message),
        ),
        (newPosts) => emit(
          currentState.copyWith(
            posts: [...currentState.posts, ...newPosts],
            hasReachedMax: newPosts.length < 20,
            isLoadingMore: false,
            error: null,
          ),
        ),
      );
    }
  }

  Future<void> _onCreatePostRequested(
    CreatePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    // 현재 FeedLoaded 상태를 미리 저장
    final prevLoaded = state is FeedLoaded ? state as FeedLoaded : null;

    emit(FeedCreatingPost());

    final result = await _createPost(
      CreatePostParams(post: event.post, images: event.images),
    );

    result.fold(
      (failure) => emit(
        FeedError(failure.message, isNetworkError: failure is NetworkFailure),
      ),
      (post) {
        AnalyticsService.instance.logPostCreated(
          postType: post.type.name,
          imageCount: post.imageUrls.length,
        );

        // 스낵바 트리거용 FeedPostCreated emit
        emit(FeedPostCreated(post));

        // 기존 피드 목록 앞에 새 게시물 추가
        final existingPosts = prevLoaded?.posts ?? [];
        emit(
          FeedLoaded(
            posts: [post, ...existingPosts],
            hasReachedMax: prevLoaded?.hasReachedMax ?? false,
          ),
        );
      },
    );
  }

  Future<void> _onLikePostRequested(
    LikePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    await _mutatePostLike(
      postId: event.postId,
      userId: event.userId,
      targetLiked: true,
      emit: emit,
      mutate: () =>
          _likePost(LikePostParams(postId: event.postId, userId: event.userId)),
    );
  }

  Future<void> _onUnlikePostRequested(
    UnlikePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    await _mutatePostLike(
      postId: event.postId,
      userId: event.userId,
      targetLiked: false,
      emit: emit,
      mutate: () => _unlikePost(
        UnlikePostParams(postId: event.postId, userId: event.userId),
      ),
    );
  }

  Future<void> _mutatePostLike({
    required String postId,
    required String userId,
    required bool targetLiked,
    required Emitter<FeedState> emit,
    required Future<Either<Failure, void>> Function() mutate,
  }) async {
    final original = _postFromState(state, postId);
    if (original == null || original.isLikedByCurrentUser == targetLiked) {
      return;
    }
    await _interactionCoordinator.setLiked(
      post: original,
      userId: userId,
      targetLiked: targetLiked,
      mutate: mutate,
      onOptimistic: (updated) => _replacePost(emit, updated),
      onRollback: (updated) => _replacePost(emit, updated),
      onReconciled: (updated) => _replacePost(emit, updated),
    );
  }

  Post? _postFromState(FeedState source, String postId) {
    final posts = switch (source) {
      FeedLoaded(:final posts) => posts,
      FeedRecommendedLoaded(:final posts) => posts,
      _ => const <Post>[],
    };
    for (final post in posts) {
      if (post.id == postId) return post;
    }
    return null;
  }

  void _emitLikeState(
    Emitter<FeedState> emit, {
    required String postId,
    required bool isLiked,
    required int likesCount,
  }) {
    final current = state;
    final posts = switch (current) {
      FeedLoaded(:final posts) => posts,
      FeedRecommendedLoaded(:final posts) => posts,
      _ => null,
    };
    if (posts == null || !posts.any((post) => post.id == postId)) return;
    final updated = posts
        .map(
          (post) => post.id == postId
              ? post.copyWith(
                  isLikedByCurrentUser: isLiked,
                  likesCount: likesCount.clamp(0, 0x7fffffff).toInt(),
                )
              : post,
        )
        .toList();
    if (current is FeedLoaded) {
      emit(current.copyWith(posts: updated));
    } else if (current is FeedRecommendedLoaded) {
      emit(current.copyWith(posts: updated));
    }
  }

  void _replacePost(Emitter<FeedState> emit, Post replacement) {
    final current = state;
    final posts = switch (current) {
      FeedLoaded(:final posts) => posts,
      FeedRecommendedLoaded(:final posts) => posts,
      _ => null,
    };
    if (posts == null ||
        !posts.any((candidate) => candidate.id == replacement.id)) {
      return;
    }
    final updated = posts
        .map(
          (candidate) =>
              candidate.id == replacement.id ? replacement : candidate,
        )
        .toList();
    if (current is FeedLoaded) {
      emit(current.copyWith(posts: updated));
    } else if (current is FeedRecommendedLoaded) {
      emit(current.copyWith(posts: updated));
    }
  }

  Future<void> _onUpdatePostRequested(
    UpdatePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (state is FeedLoaded) {
      final currentState = state as FeedLoaded;

      // 원본 상태 저장
      final originalPosts = List<Post>.from(currentState.posts);

      // 낙관적 업데이트: 먼저 UI에 반영
      final updatedPosts = currentState.posts.map((post) {
        if (post.id == event.post.id) {
          return event.post;
        }
        return post;
      }).toList();

      emit(currentState.copyWith(posts: updatedPosts));

      // 서버에 업데이트 요청
      final result = await _updatePost(UpdatePostParams(post: event.post));

      result.fold(
        (failure) {
          // 실패 시 원본 상태로 복원
          emit(currentState.copyWith(posts: originalPosts));
          emit(FeedError(failure.message));
        },
        (updatedPost) {
          // 성공 시 서버 응답으로 최종 업데이트
          final finalPosts = currentState.posts.map((post) {
            if (post.id == updatedPost.id) {
              return updatedPost;
            }
            return post;
          }).toList();
          emit(FeedPostUpdated(updatedPost));
          emit(currentState.copyWith(posts: finalPosts));
        },
      );
    }
  }

  Future<void> _onDeletePostRequested(
    DeletePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (state is FeedLoaded) {
      final currentState = state as FeedLoaded;

      // 낙관적 삭제: 먼저 UI에서 제거
      final updatedPosts =
          currentState.posts.where((post) => post.id != event.postId).toList();
      emit(currentState.copyWith(posts: updatedPosts));

      // 서버 요청
      final result = await _deletePost(DeletePostParams(postId: event.postId));

      result.fold(
        (failure) {
          // 실패 시 원복 + 에러 메시지
          emit(currentState.copyWith(error: failure.message));
        },
        (_) {
          // 성공 - 이미 UI에 반영됨
        },
      );
    }
  }

  Future<void> _onSavePostRequested(
    SavePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    final result = await _savePost(
      SavePostParams(postId: event.postId, userId: event.userId),
    );
    result.fold(
      (failure) => emit(
        FeedError(failure.message, isNetworkError: failure is NetworkFailure),
      ),
      (_) => emit(FeedPostSaved(event.postId)),
    );
  }

  Future<void> _onUnsavePostRequested(
    UnsavePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    final result = await _unsavePost(
      UnsavePostParams(postId: event.postId, userId: event.userId),
    );
    result.fold(
      (failure) => emit(
        FeedError(failure.message, isNetworkError: failure is NetworkFailure),
      ),
      (_) => emit(FeedPostUnsaved(event.postId)),
    );
  }

  Future<void> _onLoadRecommendedPostsRequested(
    LoadRecommendedPostsRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (event.offset == 0) {
      emit(FeedLoading());
    } else if (state is FeedRecommendedLoaded) {
      final current = state as FeedRecommendedLoaded;
      // 스크롤 리스너 중복 발화 대비 재진입 가드.
      if (current.hasReachedMax || current.isLoadingMore) return;
      emit(current.copyWith(isLoadingMore: true));
    }

    final result = await _socialRepository.getRecommendedPosts(
      userId: event.userId,
      limit: event.limit,
      offset: event.offset,
    );

    result.fold(
      (failure) => emit(
        FeedError(failure.message, isNetworkError: failure is NetworkFailure),
      ),
      (posts) {
        // 콜드스타트 폴백(P0-5): 추천 RPC는 본인·팔로우 글을 제외하므로
        // 초기에는 빈 결과가 날 수 있다 → 최신 전체 피드로 대체.
        // FeedLoaded 경로로 넘어가므로 keyset 무한스크롤·새로고침이 그대로 동작.
        if (event.offset == 0 && posts.isEmpty) {
          add(
            LoadFeedRequested(
              userId: event.userId,
              limit: event.limit,
              followingOnly: false,
            ),
          );
          return;
        }
        final existing = state is FeedRecommendedLoaded && event.offset > 0
            ? (state as FeedRecommendedLoaded).posts
            : <Post>[];
        emit(
          FeedRecommendedLoaded(
            posts: [...existing, ...posts],
            hasReachedMax: posts.length < event.limit,
            isLoadingMore: false,
          ),
        );
      },
    );
  }

  Future<void> _onLoadSavedPostsRequested(
    LoadSavedPostsRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(FeedLoading());
    final result = await _getSavedPosts(
      GetSavedPostsParams(userId: event.userId),
    );
    result.fold(
      (failure) => emit(
        FeedError(failure.message, isNetworkError: failure is NetworkFailure),
      ),
      (posts) => emit(FeedSavedPostsLoaded(posts)),
    );
  }

  Future<void> _onRealtimeLikeReceived(
    RealtimeLikeReceived event,
    Emitter<FeedState> emit,
  ) async {
    final postId = event.data['post_id'] as String?;
    final delta = event.data['event'] == 'insert' ? 1 : -1;
    if (postId == null || _interactionCoordinator.isPending(postId)) return;
    final post = _postFromState(state, postId);
    if (post == null) return;
    _emitLikeState(
      emit,
      postId: postId,
      isLiked: post.isLikedByCurrentUser,
      likesCount: (post.likesCount + delta).clamp(0, 0x7fffffff).toInt(),
    );
  }

  Future<void> _onRealtimeCommentReceived(
    RealtimeCommentReceived event,
    Emitter<FeedState> emit,
  ) async {
    if (state is! FeedLoaded) return;
    final current = state as FeedLoaded;
    final postId = event.data['post_id'] as String?;
    final delta = event.data['event'] == 'insert' ? 1 : -1;
    if (postId == null) return;

    final updated = current.posts.map((p) {
      if (p.id == postId) {
        return p.copyWith(
          commentsCount: (p.commentsCount + delta).clamp(0, 999999),
        );
      }
      return p;
    }).toList();
    emit(current.copyWith(posts: updated));
  }

  /// 피드 로드 후 Realtime 구독 시작
  void subscribeRealtime(String userId) {
    // 중복 구독 방지
    _likeSub?.cancel();
    _commentSub?.cancel();

    _realtimeService.subscribeToNotifications(userId);
    _likeSub = _realtimeService.likeStream.listen((data) {
      add(RealtimeLikeReceived(data));
    });
    _commentSub = _realtimeService.commentStream.listen((data) {
      add(RealtimeCommentReceived(data));
    });
  }

  @override
  Future<void> close() {
    _likeSub?.cancel();
    _commentSub?.cancel();
    return super.close();
  }
}
