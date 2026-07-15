import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/features/social/data/datasources/social_remote_data_source.dart';
import 'package:meong_nyang_diary/features/social/data/repositories/social_repository_impl.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/social_user.dart';

class _MockRemoteDataSource extends Mock implements SocialRemoteDataSource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

SocialUser _user(String id, {String name = 'Mina', String? username = 'mina'}) {
  final now = DateTime(2026, 7, 15);
  return SocialUser(
    id: id,
    email: 'private@example.com',
    displayName: name,
    username: username,
    profileImageUrl: 'https://example.com/avatar.png',
    createdAt: now,
    updatedAt: now,
  );
}

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

  test('normalizes search, clamps limit, and maps follower identity', () async {
    when(
      () => remote.getFollowers(
        'owner',
        100,
        'cursor-user',
        query: 'mina',
      ),
    ).thenAnswer((_) async => [_user('user-1')]);

    final result = await repository.getFollowersPage(
      userId: 'owner',
      limit: 150,
      lastUserId: 'cursor-user',
      query: '  @@mina  ',
    );

    expect(result.isRight(), isTrue);
    result.fold((_) => fail('expected followers'), (items) {
      expect(items.single.followerId, 'user-1');
      expect(items.single.followerName, 'Mina');
      expect(items.single.followerUsername, 'mina');
      expect(items.single.followerProfileImage, isNotNull);
    });
    verify(
      () => remote.getFollowers(
        'owner',
        100,
        'cursor-user',
        query: 'mina',
      ),
    ).called(1);
  });

  test('maps following-side identity and cursor arguments', () async {
    when(
      () => remote.getFollowing('owner', 20, null, query: ''),
    ).thenAnswer(
        (_) async => [_user('user-2', name: 'Joon', username: 'joon')]);

    final result = await repository.getFollowingPage(userId: 'owner');

    result.fold((_) => fail('expected following'), (items) {
      expect(items.single.followingId, 'user-2');
      expect(items.single.followingName, 'Joon');
      expect(items.single.followingUsername, 'joon');
    });
  });

  test('offline response never calls the remote source', () async {
    when(() => network.isConnected).thenAnswer((_) async => false);

    final result = await repository.getFollowersPage(userId: 'owner');

    expect(result.isLeft(), isTrue);
    verifyNever(
      () => remote.getFollowers(
        any(),
        any(),
        any(),
        query: any(named: 'query'),
      ),
    );
  });
}
