import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/follow.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/social_user.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/search_bloc.dart';

class _MockRepository extends Mock implements SocialRepository {}

Post _post(String id) => Post(
      id: id,
      authorId: 'author-$id',
      authorName: 'Author $id',
      type: PostType.text,
      createdAt: DateTime(2026, 7, 19),
    );

SocialUser _user(String id) => SocialUser(
      id: id,
      email: '',
      displayName: 'User $id',
      createdAt: DateTime(2026, 7, 19),
      updatedAt: DateTime(2026, 7, 19),
    );

Follow _follow(String id) => Follow(
      id: 'viewer-$id',
      followerId: 'viewer',
      followingId: id,
      followerName: 'Viewer',
      followingName: 'User $id',
      status: FollowStatus.accepted,
      createdAt: DateTime(2026, 7, 19),
    );

void main() {
  late _MockRepository repository;
  late SearchBloc bloc;

  setUp(() {
    repository = _MockRepository();
    bloc = SearchBloc(
      repository: repository,
      currentUserIdProvider: () => null,
    );
    when(
      () => repository.searchUsers(
        any(),
        limit: any(named: 'limit'),
        lastUserId: any(named: 'lastUserId'),
      ),
    ).thenAnswer((_) async => const Right([]));
    when(() => repository.getPopularHashtags(limit: any(named: 'limit')))
        .thenAnswer((_) async => const Right([]));
  });

  tearDown(() => bloc.close());

  test('a late previous query cannot overwrite the latest generation',
      () async {
    final oldResult = Completer<Either<Failure, List<Post>>>();
    when(
      () => repository.searchPosts(
        query: 'old',
        limit: any(named: 'limit'),
        lastPostId: any(named: 'lastPostId'),
      ),
    ).thenAnswer((_) => oldResult.future);
    when(
      () => repository.searchPosts(
        query: 'new',
        limit: any(named: 'limit'),
        lastPostId: any(named: 'lastPostId'),
      ),
    ).thenAnswer((_) async => Right([_post('new')]));

    bloc.add(const SearchAllRequested(query: 'old'));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const SearchAllRequested(query: 'new'));
    final latest = await bloc.stream.firstWhere(
      (state) => state.query == 'new' && state.loading.isEmpty,
    );
    expect(latest.posts.map((post) => post.id), ['new']);

    oldResult.complete(Right([_post('old')]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(bloc.state.query, 'new');
    expect(bloc.state.posts.map((post) => post.id), ['new']);
  });

  test('raw repository failure text is never exposed', () async {
    when(
      () => repository.searchPosts(
        query: 'pet',
        limit: any(named: 'limit'),
        lastPostId: any(named: 'lastPostId'),
      ),
    ).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'private backend sentinel'),
      ),
    );
    when(
      () => repository.searchUsers(
        'pet',
        limit: any(named: 'limit'),
        lastUserId: any(named: 'lastUserId'),
      ),
    ).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'private backend sentinel'),
      ),
    );
    when(() => repository.getPopularHashtags(limit: any(named: 'limit')))
        .thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'private backend sentinel'),
      ),
    );

    bloc.add(const SearchAllRequested(query: 'pet'));
    final state = await bloc.stream.firstWhere(
      (state) => state.query == 'pet' && state.loading.isEmpty,
    );
    expect(state.errors.values.join(' '), isNot(contains('sentinel')));
    expect(state.errorFor(SearchSection.all), isNotNull);
  });

  test('user load more uses the unsorted server cursor and dedupes ids',
      () async {
    final firstPage = List.generate(20, (index) => _user('u$index'));
    when(
      () => repository.searchPosts(
        query: 'user',
        limit: any(named: 'limit'),
        lastPostId: any(named: 'lastPostId'),
      ),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => repository.searchUsers(
        'user',
        limit: 20,
        lastUserId: null,
      ),
    ).thenAnswer((_) async => Right(firstPage));
    when(
      () => repository.searchUsers(
        'user',
        limit: 20,
        lastUserId: 'u19',
      ),
    ).thenAnswer((_) async => Right([_user('u19'), _user('u20')]));

    bloc.add(const SearchAllRequested(query: 'user'));
    await bloc.stream.firstWhere(
      (state) => state.query == 'user' && state.loading.isEmpty,
    );
    bloc.add(const SearchUsersRequested(query: 'user', loadMore: true));
    final state = await bloc.stream.firstWhere(
      (state) =>
          state.users.any((user) => user.id == 'u20') &&
          !state.isLoadingMore(SearchSection.users),
    );

    verify(
      () => repository.searchUsers(
        'user',
        limit: 20,
        lastUserId: 'u19',
      ),
    ).called(1);
    expect(state.users.where((user) => user.id == 'u19'), hasLength(1));
  });

  test('initial has-more uses the raw page length before dedupe', () async {
    final rawPage = [
      ...List.generate(19, (index) => _post('p$index')),
      _post('p0'),
    ];
    when(
      () => repository.searchPosts(
        query: 'pet',
        limit: 20,
        lastPostId: null,
      ),
    ).thenAnswer((_) async => Right(rawPage));

    bloc.add(const SearchAllRequested(query: 'pet'));
    final state = await bloc.stream.firstWhere(
      (state) => state.query == 'pet' && state.loading.isEmpty,
    );

    expect(state.posts, hasLength(19));
    expect(state.hasMorePosts, isTrue);
    expect(state.nextPostId, 'p0');
  });

  test('hashtag search clears users and their previous cursor', () async {
    final firstUsers = List.generate(20, (index) => _user('u$index'));
    when(
      () => repository.searchPosts(
        query: 'pet',
        limit: 20,
        lastPostId: null,
      ),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => repository.searchUsers(
        'pet',
        limit: 20,
        lastUserId: null,
      ),
    ).thenAnswer((_) async => Right(firstUsers));
    when(
      () => repository.searchPostsByHashtag(
        hashtag: 'dogs',
        limit: 20,
        lastPostId: null,
      ),
    ).thenAnswer((_) async => Right([_post('dog')]));

    bloc.add(const SearchAllRequested(query: 'pet'));
    await bloc.stream.firstWhere(
      (state) => state.query == 'pet' && state.loading.isEmpty,
    );
    expect(bloc.state.nextUserId, 'u19');

    bloc.add(const SearchPostsByHashtagRequested(hashtag: 'dogs'));
    final state = await bloc.stream.firstWhere(
      (state) => state.query == '#dogs' && state.loading.isEmpty,
    );

    expect(state.posts.map((post) => post.id), ['dog']);
    expect(state.users, isEmpty);
    expect(state.hashtags, isEmpty);
    expect(state.hasMoreUsers, isFalse);
    expect(state.nextUserId, isNull);
  });

  test('hashtag first page preserves the raw cursor before dedupe', () async {
    final rawPage = [
      ...List.generate(19, (index) => _post('tag-$index')),
      _post('tag-0'),
    ];
    when(
      () => repository.searchPostsByHashtag(
        hashtag: 'dogs',
        limit: 20,
        lastPostId: null,
      ),
    ).thenAnswer((_) async => Right(rawPage));

    bloc.add(const SearchPostsByHashtagRequested(hashtag: 'dogs'));
    final state = await bloc.stream.firstWhere(
      (state) => state.query == '#dogs' && state.loading.isEmpty,
    );

    expect(state.posts, hasLength(19));
    expect(state.hasMorePosts, isTrue);
    expect(state.nextPostId, 'tag-0');
  });

  test('following-first sort includes following beyond the first 50', () async {
    final pagedBloc = SearchBloc(
      repository: repository,
      currentUserIdProvider: () => 'viewer',
    );
    addTearDown(pagedBloc.close);
    when(
      () => repository.searchPosts(
        query: 'user',
        limit: 20,
        lastPostId: null,
      ),
    ).thenAnswer((_) async => const Right([]));
    when(
      () => repository.searchUsers(
        'user',
        limit: 20,
        lastUserId: null,
      ),
    ).thenAnswer((_) async => Right([_user('other'), _user('u100')]));
    when(
      () => repository.getFollowingPage(
        userId: 'viewer',
        limit: 100,
        lastUserId: null,
      ),
    ).thenAnswer(
      (_) async => Right(List.generate(100, (index) => _follow('u$index'))),
    );
    when(
      () => repository.getFollowingPage(
        userId: 'viewer',
        limit: 100,
        lastUserId: 'u99',
      ),
    ).thenAnswer((_) async => Right([_follow('u100')]));

    pagedBloc.add(const SearchAllRequested(query: 'user'));
    final state = await pagedBloc.stream.firstWhere(
      (state) => state.query == 'user' && state.loading.isEmpty,
    );

    expect(state.followingIds, contains('u100'));
    expect(state.users.first.id, 'u100');
    verify(
      () => repository.getFollowingPage(
        userId: 'viewer',
        limit: 100,
        lastUserId: 'u99',
      ),
    ).called(1);
  });

  test('each new search refreshes following-first ordering', () async {
    final followingBloc = SearchBloc(
      repository: repository,
      currentUserIdProvider: () => 'viewer',
    );
    addTearDown(followingBloc.close);
    for (final query in ['first', 'second']) {
      when(
        () => repository.searchPosts(
          query: query,
          limit: 20,
          lastPostId: null,
        ),
      ).thenAnswer((_) async => const Right([]));
      when(
        () => repository.searchUsers(
          query,
          limit: 20,
          lastUserId: null,
        ),
      ).thenAnswer((_) async => Right([_user('u1'), _user('u2')]));
    }
    var followingRequest = 0;
    when(
      () => repository.getFollowingPage(
        userId: 'viewer',
        limit: 100,
        lastUserId: null,
      ),
    ).thenAnswer((_) async {
      followingRequest++;
      return Right([_follow(followingRequest == 1 ? 'u1' : 'u2')]);
    });

    followingBloc.add(const SearchAllRequested(query: 'first'));
    final first = await followingBloc.stream.firstWhere(
      (state) => state.query == 'first' && state.loading.isEmpty,
    );
    expect(first.users.first.id, 'u1');

    followingBloc.add(const SearchAllRequested(query: 'second'));
    final second = await followingBloc.stream.firstWhere(
      (state) => state.query == 'second' && state.loading.isEmpty,
    );
    expect(second.users.first.id, 'u2');
    verify(
      () => repository.getFollowingPage(
        userId: 'viewer',
        limit: 100,
        lastUserId: null,
      ),
    ).called(2);
  });
}
