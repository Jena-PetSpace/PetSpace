import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post.dart';
import '../../domain/usecases/delete_post.dart';
import '../../domain/usecases/get_feed.dart';
import '../../domain/usecases/like_post.dart';
import '../../domain/usecases/unlike_post.dart';
import '../../domain/usecases/save_post.dart';
import '../../../../core/services/realtime_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../domain/usecases/unsave_post.dart';
import '../../domain/usecases/get_saved_posts.dart';
import '../../domain/usecases/update_post.dart';
import '../../domain/repositories/social_repository.dart';

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
  final PushNotificationService _pushService = PushNotificationService();
  StreamSubscription<Map<String, dynamic>>? _likeSub;
  StreamSubscription<Map<String, dynamic>>? _commentSub;

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

    final result = await _getFeed(GetFeedParams(
      userId: event.userId,
      limit: event.limit,
      followingOnly: event.followingOnly,
    ));

    result.fold(
      (failure) => emit(FeedError(failure.message, isNetworkError: failure is NetworkFailure)),
      (posts) => emit(FeedLoaded(
        posts: posts,
        hasReachedMax: posts.length < event.limit,
      )),
    );
  }

  Future<void> _onRefreshFeedRequested(
    RefreshFeedRequested event,
    Emitter<FeedState> emit,
  ) async {
    final result = await _getFeed(GetFeedParams(
      userId: event.userId,
      limit: 20,
      followingOnly: event.followingOnly,
    ));

    result.fold(
      (failure) => emit(FeedError(failure.message, isNetworkError: failure is NetworkFailure)),
      (posts) => emit(FeedLoaded(
        posts: posts,
        hasReachedMax: posts.length < 20,
      )),
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

      final result = await _getFeed(GetFeedParams(
        userId: event.userId,
        limit: 20,
        lastPostId: currentState.posts.isNotEmpty ? currentState.posts.last.id : null,
        lastCreatedAt: currentState.posts.isNotEmpty ? currentState.posts.last.createdAt : null,
        followingOnly: event.followingOnly,
      ));

      result.fold(
        (failure) => emit(currentState.copyWith(
          isLoadingMore: false,
          error: failure.message,
        )),
        (newPosts) => emit(currentState.copyWith(
          posts: [...currentState.posts, ...newPosts],
          hasReachedMax: newPosts.length < 20,
          isLoadingMore: false,
          error: null,
        )),
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

    final result = await _createPost(CreatePostParams(post: event.post, images: event.images));

    result.fold(
      (failure) => emit(FeedError(failure.message, isNetworkError: failure is NetworkFailure)),
      (post) {
        // 스낵바 트리거용 FeedPostCreated emit
        emit(FeedPostCreated(post));

        // 기존 피드 목록 앞에 새 게시물 추가
        final existingPosts = prevLoaded?.posts ?? [];
        emit(FeedLoaded(
          posts: [post, ...existingPosts],
          hasReachedMax: prevLoaded?.hasReachedMax ?? false,
        ));
      },
    );
  }

  Future<void> _onLikePostRequested(
    LikePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    List<Post> posts;
    if (current is FeedLoaded) {
      posts = current.posts;
    } else if (current is FeedRecommendedLoaded) {
      posts = current.posts;
    } else {
      return;
    }

    final originalPosts = List<Post>.from(posts);
    final updatedPosts = posts.map((post) {
      if (post.id == event.postId) {
        return post.copyWith(
          isLikedByCurrentUser: true,
          likesCount: post.likesCount + 1,
        );
      }
      return post;
    }).toList();

    if (current is FeedLoaded) {
      emit(current.copyWith(posts: updatedPosts));
    } else if (current is FeedRecommendedLoaded) {
      emit(current.copyWith(posts: updatedPosts));
    }

    final result = await _likePost(LikePostParams(
      postId: event.postId,
      userId: event.userId,
    ));

    result.fold(
      (_) {
        // 실패 시 원본 상태로 복원
        if (current is FeedLoaded) {
          emit(current.copyWith(posts: originalPosts));
        } else if (current is FeedRecommendedLoaded) {
          emit(current.copyWith(posts: originalPosts));
        }
      },
      (_) {
        final likedPost =
            posts.where((p) => p.id == event.postId).firstOrNull;
        if (likedPost != null && likedPost.authorId != event.userId) {
          _pushService.sendLikeNotification(
            toUserId: likedPost.authorId,
            fromUserId: event.userId,
            fromUserName: '사용자',
            postId: event.postId,
          );
        }
      },
    );
  }

  Future<void> _onUnlikePostRequested(
    UnlikePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    List<Post> posts;
    if (current is FeedLoaded) {
      posts = current.posts;
    } else if (current is FeedRecommendedLoaded) {
      posts = current.posts;
    } else {
      return;
    }

    final originalPosts = List<Post>.from(posts);
    final updatedPosts = posts.map((post) {
      if (post.id == event.postId) {
        return post.copyWith(
          isLikedByCurrentUser: false,
          likesCount: post.likesCount - 1,
        );
      }
      return post;
    }).toList();

    if (current is FeedLoaded) {
      emit(current.copyWith(posts: updatedPosts));
    } else if (current is FeedRecommendedLoaded) {
      emit(current.copyWith(posts: updatedPosts));
    }

    final result = await _unlikePost(UnlikePostParams(
      postId: event.postId,
      userId: event.userId,
    ));

    result.fold(
      (_) {
        if (current is FeedLoaded) {
          emit(current.copyWith(posts: originalPosts));
        } else if (current is FeedRecommendedLoaded) {
          emit(current.copyWith(posts: originalPosts));
        }
      },
      (_) {},
    );
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
        SavePostParams(postId: event.postId, userId: event.userId));
    result.fold(
      (failure) => emit(FeedError(failure.message, isNetworkError: failure is NetworkFailure)),
      (_) => emit(FeedPostSaved(event.postId)),
    );
  }

  Future<void> _onUnsavePostRequested(
    UnsavePostRequested event,
    Emitter<FeedState> emit,
  ) async {
    final result = await _unsavePost(
        UnsavePostParams(postId: event.postId, userId: event.userId));
    result.fold(
      (failure) => emit(FeedError(failure.message, isNetworkError: failure is NetworkFailure)),
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
      if (current.hasReachedMax) return;
      emit(current.copyWith(isLoadingMore: true));
    }

    final result = await _socialRepository.getRecommendedPosts(
      userId: event.userId,
      limit: event.limit,
      offset: event.offset,
    );

    result.fold(
      (failure) => emit(FeedError(failure.message, isNetworkError: failure is NetworkFailure)),
      (posts) {
        final existing = state is FeedRecommendedLoaded && event.offset > 0
            ? (state as FeedRecommendedLoaded).posts
            : <Post>[];
        emit(FeedRecommendedLoaded(
          posts: [...existing, ...posts],
          hasReachedMax: posts.length < event.limit,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> _onLoadSavedPostsRequested(
    LoadSavedPostsRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(FeedLoading());
    final result =
        await _getSavedPosts(GetSavedPostsParams(userId: event.userId));
    result.fold(
      (failure) => emit(FeedError(failure.message, isNetworkError: failure is NetworkFailure)),
      (posts) => emit(FeedSavedPostsLoaded(posts)),
    );
  }

  Future<void> _onRealtimeLikeReceived(
    RealtimeLikeReceived event,
    Emitter<FeedState> emit,
  ) async {
    if (state is! FeedLoaded) return;
    final current = state as FeedLoaded;
    final postId = event.data['post_id'] as String?;
    final delta = event.data['event'] == 'insert' ? 1 : -1;
    if (postId == null) return;

    final updated = current.posts.map((p) {
      if (p.id == postId) {
        return p.copyWith(likesCount: (p.likesCount + delta).clamp(0, 999999));
      }
      return p;
    }).toList();
    emit(current.copyWith(posts: updated));
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
            commentsCount: (p.commentsCount + delta).clamp(0, 999999));
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
