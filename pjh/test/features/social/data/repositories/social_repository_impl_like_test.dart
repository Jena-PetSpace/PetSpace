import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/features/social/data/datasources/social_remote_data_source.dart';
import 'package:meong_nyang_diary/features/social/data/repositories/social_repository_impl.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post_likes_page.dart';

class _MockRemoteDataSource extends Mock implements SocialRemoteDataSource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late _MockRemoteDataSource remote;
  late _MockNetworkInfo network;
  late SocialRepositoryImpl repository;

  setUp(() {
    remote = _MockRemoteDataSource();
    network = _MockNetworkInfo();
    repository = SocialRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
    when(() => network.isConnected).thenAnswer((_) async => true);
  });

  test('normalizes @ search and clamps page size before remote request',
      () async {
    when(
      () => remote.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: null,
        query: 'mina',
        limit: 100,
      ),
    ).thenAnswer(
      (_) async => const PostLikesPage(items: [], hasMore: false),
    );

    final result = await repository.getPostLikesPage(
      postId: 'post-1',
      currentUserId: 'viewer',
      query: '  @@mina  ',
      limit: 500,
    );

    expect(result.isRight(), isTrue);
    verify(
      () => remote.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: null,
        query: 'mina',
        limit: 100,
      ),
    ).called(1);
  });

  test('offline request does not access the remote source', () async {
    when(() => network.isConnected).thenAnswer((_) async => false);

    final result = await repository.getPostLikesPage(
      postId: 'post-1',
      currentUserId: 'viewer',
    );

    expect(result.isLeft(), isTrue);
    verifyNever(
      () => remote.getPostLikesPage(
        postId: any(named: 'postId'),
        currentUserId: any(named: 'currentUserId'),
        cursor: any(named: 'cursor'),
        query: any(named: 'query'),
        limit: any(named: 'limit'),
      ),
    );
  });

  test('remote error is mapped to a safe public message', () async {
    when(
      () => remote.getPostLikesPage(
        postId: any(named: 'postId'),
        currentUserId: any(named: 'currentUserId'),
        cursor: any(named: 'cursor'),
        query: any(named: 'query'),
        limit: any(named: 'limit'),
      ),
    ).thenThrow(StateError('database-secret'));

    final result = await repository.getPostLikesPage(
      postId: 'post-1',
      currentUserId: 'viewer',
    );

    result.fold(
      (failure) {
        expect(failure.message, isNot(contains('database-secret')));
        expect(failure.message, contains('다시 시도'));
      },
      (_) => fail('Failure expected'),
    );
  });
}
