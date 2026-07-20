import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/features/social/data/datasources/social_remote_data_source.dart';
import 'package:meong_nyang_diary/features/social/data/repositories/social_repository_impl.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/blocked_user.dart';

class _Remote extends Mock implements SocialRemoteDataSource {}

class _Network extends Mock implements NetworkInfo {}

void main() {
  late _Remote remote;
  late _Network network;
  late SocialRepositoryImpl repository;

  setUp(() {
    remote = _Remote();
    network = _Network();
    repository = SocialRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: network,
    );
    when(() => network.isConnected).thenAnswer((_) async => true);
  });

  test('normalizes query, caps limit, and maps the composite cursor', () async {
    final user = BlockedUser(
      id: 'blocked',
      blockId: 'block-row',
      displayName: 'Blocked',
      blockedAt: DateTime.utc(2026, 7, 19),
    );
    when(
      () => remote.getBlockedUsers(query: 'name', limit: 20, cursor: null),
    ).thenAnswer((_) async => [user]);

    final result = await repository.getBlockedUsers(
      query: '  @@ name  ',
      limit: 100,
    );

    expect(result.isRight(), isTrue);
    verify(
      () => remote.getBlockedUsers(query: 'name', limit: 20, cursor: null),
    ).called(1);
  });

  test('offline is propagated as NetworkFailure', () async {
    when(() => network.isConnected).thenAnswer((_) async => false);
    final result = await repository.getBlockedUsers();
    expect(
      result.fold((failure) => failure, (_) => null),
      isA<NetworkFailure>(),
    );
  });

  test('forwards the same composite cursor for the next page', () async {
    final cursor = BlockedUsersCursor(
      blockedAt: DateTime.utc(2026, 7, 18),
      blockId: 'cursor-row',
    );
    when(
      () => remote.getBlockedUsers(query: '', limit: 20, cursor: cursor),
    ).thenAnswer((_) async => const []);

    final result = await repository.getBlockedUsers(cursor: cursor);

    expect(result.isRight(), isTrue);
    verify(
      () => remote.getBlockedUsers(query: '', limit: 20, cursor: cursor),
    ).called(1);
  });

  test('block and unblock delegate without accepting a blocker id', () async {
    when(() => remote.blockUser('target')).thenAnswer((_) async {});
    when(() => remote.unblockUser('target')).thenAnswer((_) async {});

    expect((await repository.blockUser('target')).isRight(), isTrue);
    expect((await repository.unblockUser('target')).isRight(), isTrue);
    verify(() => remote.blockUser('target')).called(1);
    verify(() => remote.unblockUser('target')).called(1);
  });

  test('server errors become Failure values', () async {
    when(
      () => remote.getBlockedUsers(query: '', limit: 20, cursor: null),
    ).thenThrow(StateError('rls'));
    final result = await repository.getBlockedUsers();
    expect(
      result.fold((failure) => failure, (_) => null),
      isA<ServerFailure>(),
    );
  });

  test('RLS details are not exposed by block operations', () async {
    when(
      () => remote.blockUser('target'),
    ).thenThrow(StateError('new row violates row-level security policy'));

    final result = await repository.blockUser('target');
    final failure = result.fold((value) => value, (_) => null);

    expect(failure, isA<ServerFailure>());
    expect(failure!.message, '차단 요청을 처리하지 못했습니다. 다시 시도해 주세요.');
    expect(failure.message, isNot(contains('row-level security')));
  });
}
