import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/features/social/data/datasources/social_remote_data_source.dart';
import 'package:meong_nyang_diary/features/social/data/repositories/social_repository_impl.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/social_user.dart';

class _MockRemote extends Mock implements SocialRemoteDataSource {}

class _MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late _MockRemote remote;
  late _MockNetworkInfo networkInfo;
  late SocialRepositoryImpl repository;

  setUp(() {
    remote = _MockRemote();
    networkInfo = _MockNetworkInfo();
    repository = SocialRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: networkInfo,
    );
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
  });

  test('forwards the user cursor and page size unchanged', () async {
    when(() => remote.searchUsers('mina', 30, 'cursor-user')).thenAnswer(
      (_) async => [
        SocialUser(
          id: 'next-user',
          email: '',
          displayName: 'Mina',
          createdAt: DateTime(2026, 7, 19),
          updatedAt: DateTime(2026, 7, 19),
        ),
      ],
    );

    final result = await repository.searchUsers(
      'mina',
      limit: 30,
      lastUserId: 'cursor-user',
    );

    expect(result.isRight(), isTrue);
    verify(() => remote.searchUsers('mina', 30, 'cursor-user')).called(1);
  });

  test('offline user search does not touch the remote source', () async {
    when(() => networkInfo.isConnected).thenAnswer((_) async => false);

    final result = await repository.searchUsers(
      'mina',
      lastUserId: 'cursor-user',
    );

    expect(result.isLeft(), isTrue);
    verifyNever(() => remote.searchUsers(any(), any(), any()));
  });
}
