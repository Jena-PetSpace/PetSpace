import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/features/social/data/datasources/social_remote_data_source.dart';
import 'package:meong_nyang_diary/features/social/data/repositories/social_repository_impl.dart';

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

  test('comment report reaches the existing remote contract', () async {
    when(
      () => remote.reportComment('comment-1', 'viewer', '스팸 또는 광고'),
    ).thenAnswer((_) async {});

    final result = await repository.reportComment(
      'comment-1',
      'viewer',
      '스팸 또는 광고',
    );

    expect(result.isRight(), isTrue);
    verify(
      () => remote.reportComment('comment-1', 'viewer', '스팸 또는 광고'),
    ).called(1);
  });

  test('offline report never reaches the remote source', () async {
    when(() => network.isConnected).thenAnswer((_) async => false);

    final result = await repository.reportComment(
      'comment-1',
      'viewer',
      '기타',
    );

    expect(result.isLeft(), isTrue);
    verifyNever(() => remote.reportComment(any(), any(), any()));
  });

  test('remote report failure never exposes raw backend text', () async {
    when(
      () => remote.reportComment(any(), any(), any()),
    ).thenThrow(StateError('database-secret'));

    final result = await repository.reportComment(
      'comment-1',
      'viewer',
      '기타',
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
