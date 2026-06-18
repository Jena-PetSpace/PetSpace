import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/feed_hub/presentation/cubit/community_cubit.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';

class MockSocialRepository extends Mock implements SocialRepository {}

Map<String, dynamic> _row(String id, String createdAt) => {
      'id': id,
      'author_id': 'u-$id',
      'caption': '본문 $id',
      'hashtags': const ['community', 'health'],
      'likes_count': 0,
      'comments_count': 0,
      'created_at': createdAt,
      'users': const {'display_name': '집사', 'photo_url': null},
    };

/// limit개의 더미 행을 생성 (created_at 내림차순).
List<Map<String, dynamic>> _rows(int n, {int startIndex = 0}) => List.generate(
      n,
      (i) {
        final idx = startIndex + i;
        final day = (28 - idx).clamp(1, 28);
        return _row('p$idx', '2026-06-${day.toString().padLeft(2, '0')}T00:00:00.000Z');
      },
    );

void main() {
  late MockSocialRepository repo;

  setUp(() {
    repo = MockSocialRepository();
  });

  group('초기 상태', () {
    test('CommunityState.initial', () {
      final cubit = CommunityCubit(repository: repo);
      expect(cubit.state.status, CommunityStatus.initial);
      expect(cubit.state.posts, isEmpty);
    });
  });

  group('loadCategory', () {
    blocTest<CommunityCubit, CommunityState>(
      '로드 성공 → loading → loaded(글 매핑됨)',
      build: () {
        when(() => repo.getCommunityPosts(
                category: any(named: 'category'),
                limit: any(named: 'limit'),
                beforeCreatedAt: any(named: 'beforeCreatedAt')))
            .thenAnswer((_) async => Right(_rows(3)));
        return CommunityCubit(repository: repo);
      },
      act: (c) => c.loadCategory(null),
      expect: () => [
        isA<CommunityState>()
            .having((s) => s.status, 'status', CommunityStatus.loading),
        isA<CommunityState>()
            .having((s) => s.status, 'status', CommunityStatus.loaded)
            .having((s) => s.posts.length, 'posts', 3),
      ],
    );

    blocTest<CommunityCubit, CommunityState>(
      '로드 실패 → loading → error',
      build: () {
        when(() => repo.getCommunityPosts(
                category: any(named: 'category'),
                limit: any(named: 'limit'),
                beforeCreatedAt: any(named: 'beforeCreatedAt')))
            .thenAnswer((_) async =>
                const Left(ServerFailure(message: '서버 오류')));
        return CommunityCubit(repository: repo);
      },
      act: (c) => c.loadCategory(null),
      expect: () => [
        isA<CommunityState>()
            .having((s) => s.status, 'status', CommunityStatus.loading),
        isA<CommunityState>()
            .having((s) => s.status, 'status', CommunityStatus.error),
      ],
    );

    blocTest<CommunityCubit, CommunityState>(
      'limit 미만 반환 시 hasReachedMax=true',
      build: () {
        when(() => repo.getCommunityPosts(
                category: any(named: 'category'),
                limit: any(named: 'limit'),
                beforeCreatedAt: any(named: 'beforeCreatedAt')))
            .thenAnswer((_) async => Right(_rows(3)));
        return CommunityCubit(repository: repo);
      },
      act: (c) => c.loadCategory(null),
      verify: (c) => expect(c.state.hasReachedMax, true),
    );

    blocTest<CommunityCubit, CommunityState>(
      '카테고리 전환 시 이전 카테고리의 hasReachedMax/isLoadingMore를 리셋한다',
      build: () {
        var call = 0;
        when(() => repo.getCommunityPosts(
                category: any(named: 'category'),
                limit: any(named: 'limit'),
                beforeCreatedAt: any(named: 'beforeCreatedAt')))
            .thenAnswer((_) async {
          // 1번째(전체): 3개 → hasReachedMax=true
          // 2번째(health): 30개 → hasReachedMax=false 여야 함
          return Right(call++ == 0 ? _rows(3) : _rows(30));
        });
        return CommunityCubit(repository: repo);
      },
      act: (c) async {
        await c.loadCategory(null); // reachedMax=true 상태로 만듦
        await c.loadCategory('health'); // 전환
      },
      verify: (c) {
        expect(c.state.category, 'health');
        expect(c.state.posts.length, 30);
        expect(c.state.hasReachedMax, false);
        expect(c.state.isLoadingMore, false);
      },
    );

    blocTest<CommunityCubit, CommunityState>(
      '카테고리 전환 시 해당 카테고리로 재조회하고 목록을 교체한다',
      build: () {
        when(() => repo.getCommunityPosts(
                category: any(named: 'category'),
                limit: any(named: 'limit'),
                beforeCreatedAt: any(named: 'beforeCreatedAt')))
            .thenAnswer((_) async => Right(_rows(2)));
        return CommunityCubit(repository: repo);
      },
      act: (c) => c.loadCategory('health'),
      verify: (c) {
        verify(() => repo.getCommunityPosts(
            category: 'health',
            limit: any(named: 'limit'),
            beforeCreatedAt: null)).called(1);
        expect(c.state.category, 'health');
      },
    );
  });

  group('loadMore', () {
    blocTest<CommunityCubit, CommunityState>(
      '첫 페이지가 가득 차면 loadMore가 다음 페이지를 append한다',
      build: () {
        // 1st: limit(30) 가득 → hasReachedMax=false
        // 2nd: 5개 → append + hasReachedMax=true
        final responses = [
          Right<Failure, List<Map<String, dynamic>>>(_rows(30)),
          Right<Failure, List<Map<String, dynamic>>>(_rows(5, startIndex: 30)),
        ];
        var call = 0;
        when(() => repo.getCommunityPosts(
                category: any(named: 'category'),
                limit: any(named: 'limit'),
                beforeCreatedAt: any(named: 'beforeCreatedAt')))
            .thenAnswer((_) async => responses[call++]);
        return CommunityCubit(repository: repo);
      },
      act: (c) async {
        await c.loadCategory(null);
        await c.loadMore();
      },
      verify: (c) {
        expect(c.state.posts.length, 35);
        expect(c.state.hasReachedMax, true);
        // 2번째 호출은 첫 페이지 마지막 글의 created_at을 커서로 넘긴다
        final captured = verify(() => repo.getCommunityPosts(
            category: any(named: 'category'),
            limit: any(named: 'limit'),
            beforeCreatedAt: captureAny(named: 'beforeCreatedAt'))).captured;
        expect(captured.last, isNotNull);
      },
    );

    blocTest<CommunityCubit, CommunityState>(
      'hasReachedMax 상태면 loadMore는 추가 조회하지 않는다',
      build: () {
        when(() => repo.getCommunityPosts(
                category: any(named: 'category'),
                limit: any(named: 'limit'),
                beforeCreatedAt: any(named: 'beforeCreatedAt')))
            .thenAnswer((_) async => Right(_rows(3))); // limit 미만 → reachedMax
        return CommunityCubit(repository: repo);
      },
      act: (c) async {
        await c.loadCategory(null);
        clearInteractions(repo);
        await c.loadMore();
      },
      verify: (c) {
        verifyNever(() => repo.getCommunityPosts(
            category: any(named: 'category'),
            limit: any(named: 'limit'),
            beforeCreatedAt: any(named: 'beforeCreatedAt')));
      },
    );
  });
}
