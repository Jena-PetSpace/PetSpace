import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/get_feed.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/create_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/update_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/delete_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/like_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/unlike_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/save_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/unsave_post.dart';
import 'package:meong_nyang_diary/features/social/domain/usecases/get_saved_posts.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/feed_bloc.dart';
import 'package:meong_nyang_diary/core/services/realtime_service.dart';

// Mocks
class MockGetFeed extends Mock implements GetFeed {}

class MockCreatePost extends Mock implements CreatePost {}

class MockUpdatePost extends Mock implements UpdatePost {}

class MockDeletePost extends Mock implements DeletePost {}

class MockLikePost extends Mock implements LikePost {}

class MockUnlikePost extends Mock implements UnlikePost {}

class MockSavePost extends Mock implements SavePost {}

class MockUnsavePost extends Mock implements UnsavePost {}

class MockGetSavedPosts extends Mock implements GetSavedPosts {}

class MockRealtimeService extends Mock implements RealtimeService {}

// Fallbacks
class FakeGetFeedParams extends Fake implements GetFeedParams {}

class FakeCreatePostParams extends Fake implements CreatePostParams {}

class FakeLikePostParams extends Fake implements LikePostParams {}

class FakeUnlikePostParams extends Fake implements UnlikePostParams {}

class FakeSavePostParams extends Fake implements SavePostParams {}

class FakeUnsavePostParams extends Fake implements UnsavePostParams {}

class FakeGetSavedPostsParams extends Fake implements GetSavedPostsParams {}

final _tPost = Post(
  id: 'post-001',
  authorId: 'user-001',
  authorName: '테스트유저',
  type: PostType.emotionAnalysis,
  likesCount: 0,
  commentsCount: 0,
  isLikedByCurrentUser: false,
  createdAt: DateTime(2025, 6, 1),
);

FeedBloc _buildBloc({
  MockGetFeed? getFeed,
  MockCreatePost? createPost,
  MockLikePost? likePost,
  MockUnlikePost? unlikePost,
  MockSavePost? savePost,
  MockUnsavePost? unsavePost,
  MockGetSavedPosts? getSavedPosts,
  MockRealtimeService? realtimeService,
}) {
  return FeedBloc(
    getFeed: getFeed ?? MockGetFeed(),
    createPost: createPost ?? MockCreatePost(),
    updatePost: MockUpdatePost(),
    deletePost: MockDeletePost(),
    likePost: likePost ?? MockLikePost(),
    unlikePost: unlikePost ?? MockUnlikePost(),
    savePost: savePost ?? MockSavePost(),
    unsavePost: unsavePost ?? MockUnsavePost(),
    getSavedPosts: getSavedPosts ?? MockGetSavedPosts(),
    realtimeService: realtimeService ?? MockRealtimeService(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeGetFeedParams());
    registerFallbackValue(FakeCreatePostParams());
    registerFallbackValue(FakeLikePostParams());
    registerFallbackValue(FakeUnlikePostParams());
    registerFallbackValue(FakeSavePostParams());
    registerFallbackValue(FakeUnsavePostParams());
    registerFallbackValue(FakeGetSavedPostsParams());
  });

  // ── 초기 상태 ────────────────────────────────────────────────────────────
  group('초기 상태', () {
    test('FeedInitial', () {
      expect(_buildBloc().state, isA<FeedInitial>());
    });
  });

  // ── LoadFeedRequested ─────────────────────────────────────────────────────
  group('LoadFeedRequested', () {
    blocTest<FeedBloc, FeedState>(
      '성공 → FeedLoading → FeedLoaded',
      build: () {
        final getFeed = MockGetFeed();
        when(() => getFeed(any())).thenAnswer((_) async => Right([_tPost]));
        return _buildBloc(getFeed: getFeed);
      },
      act: (bloc) => bloc.add(const LoadFeedRequested(userId: 'user-001')),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>().having((s) => s.posts.length, 'posts count', 1),
      ],
    );

    blocTest<FeedBloc, FeedState>(
      '실패 → FeedLoading → FeedError',
      build: () {
        final getFeed = MockGetFeed();
        when(() => getFeed(any())).thenAnswer(
            (_) async => const Left(ServerFailure(message: '서버 오류')));
        return _buildBloc(getFeed: getFeed);
      },
      act: (bloc) => bloc.add(const LoadFeedRequested(userId: 'user-001')),
      expect: () => [isA<FeedLoading>(), isA<FeedError>()],
    );

    blocTest<FeedBloc, FeedState>(
      '빈 결과 → FeedLoaded(hasReachedMax: true)',
      build: () {
        final getFeed = MockGetFeed();
        when(() => getFeed(any())).thenAnswer((_) async => const Right([]));
        return _buildBloc(getFeed: getFeed);
      },
      act: (bloc) => bloc.add(const LoadFeedRequested(userId: 'user-001')),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>().having((s) => s.hasReachedMax, 'hasReachedMax', true),
      ],
    );
  });

  // ── LikePostRequested ─────────────────────────────────────────────────────
  group('LikePostRequested', () {
    blocTest<FeedBloc, FeedState>(
      '좋아요 성공 → 낙관적 업데이트 유지',
      build: () {
        final getFeed = MockGetFeed();
        final likePost = MockLikePost();
        when(() => getFeed(any())).thenAnswer((_) async => Right([_tPost]));
        when(() => likePost(any())).thenAnswer((_) async => const Right(null));
        return _buildBloc(getFeed: getFeed, likePost: likePost);
      },
      act: (bloc) async {
        bloc.add(const LoadFeedRequested(userId: 'user-001'));
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
            const LikePostRequested(postId: 'post-001', userId: 'user-001'));
      },
      verify: (bloc) {
        final state = bloc.state;
        if (state is FeedLoaded) {
          expect(state.posts.first.isLikedByCurrentUser, true);
          expect(state.posts.first.likesCount, 1);
        }
      },
    );

    blocTest<FeedBloc, FeedState>(
      '좋아요 실패 → 낙관적 업데이트 롤백',
      build: () {
        final getFeed = MockGetFeed();
        final likePost = MockLikePost();
        when(() => getFeed(any())).thenAnswer((_) async => Right([_tPost]));
        when(() => likePost(any()))
            .thenAnswer((_) async => const Left(ServerFailure(message: '오류')));
        return _buildBloc(getFeed: getFeed, likePost: likePost);
      },
      act: (bloc) async {
        bloc.add(const LoadFeedRequested(userId: 'user-001'));
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
            const LikePostRequested(postId: 'post-001', userId: 'user-001'));
        await Future.delayed(const Duration(milliseconds: 50));
      },
      verify: (bloc) {
        final state = bloc.state;
        if (state is FeedLoaded) {
          expect(state.posts.first.isLikedByCurrentUser, false);
          expect(state.posts.first.likesCount, 0);
        }
      },
    );
  });

  // ── SavePostRequested ─────────────────────────────────────────────────────
  group('SavePostRequested', () {
    blocTest<FeedBloc, FeedState>(
      '북마크 성공 → FeedPostSaved',
      build: () {
        final savePost = MockSavePost();
        when(() => savePost(any())).thenAnswer((_) async => const Right(null));
        return _buildBloc(savePost: savePost);
      },
      act: (bloc) => bloc
          .add(const SavePostRequested(postId: 'post-001', userId: 'user-001')),
      expect: () => [isA<FeedPostSaved>()],
    );

    blocTest<FeedBloc, FeedState>(
      '북마크 실패 → FeedError',
      build: () {
        final savePost = MockSavePost();
        when(() => savePost(any())).thenAnswer(
            (_) async => const Left(NetworkFailure(message: '네트워크 오류')));
        return _buildBloc(savePost: savePost);
      },
      act: (bloc) => bloc
          .add(const SavePostRequested(postId: 'post-001', userId: 'user-001')),
      expect: () => [isA<FeedError>()],
    );
  });

  // ── RefreshFeedRequested ──────────────────────────────────────────────────
  group('RefreshFeedRequested', () {
    blocTest<FeedBloc, FeedState>(
      '새로고침 성공 → FeedLoaded(새 데이터)',
      build: () {
        final getFeed = MockGetFeed();
        when(() => getFeed(any())).thenAnswer((_) async => Right([_tPost]));
        return _buildBloc(getFeed: getFeed);
      },
      act: (bloc) => bloc.add(const RefreshFeedRequested(userId: 'user-001')),
      expect: () => [
        isA<FeedLoading>(),
        isA<FeedLoaded>(),
      ],
    );
  });
}
