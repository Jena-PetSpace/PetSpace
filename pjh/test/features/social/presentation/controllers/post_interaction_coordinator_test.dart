import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/controllers/post_interaction_coordinator.dart';

class _MockRepository extends Mock implements SocialRepository {}

Post _post() => Post(
      id: 'post-1',
      authorId: 'author-1',
      authorName: 'Mina',
      type: PostType.text,
      content: 'hello',
      createdAt: DateTime(2026, 7, 19),
      likesCount: 2,
    );

void main() {
  late _MockRepository repository;
  late PostInteractionCoordinator coordinator;

  setUp(() {
    repository = _MockRepository();
    coordinator = PostInteractionCoordinator(repository: repository);
    when(() => repository.getPost('post-1')).thenAnswer(
      (_) async => Right(_post().copyWith(
        likesCount: 3,
        isLikedByCurrentUser: true,
      )),
    );
    when(() => repository.isPostLiked('post-1', 'viewer')).thenAnswer(
      (_) async => const Right(true),
    );
  });

  test('different callers share one pending lock and one mutation', () async {
    final completer = Completer<Either<Failure, void>>();
    var mutationCalls = 0;
    Future<Either<Failure, void>> mutate() {
      mutationCalls++;
      return completer.future;
    }

    final first = coordinator.setLiked(
      post: _post(),
      userId: 'viewer',
      targetLiked: true,
      mutate: mutate,
      onOptimistic: (_) {},
      onRollback: (_) {},
      onReconciled: (_) {},
    );
    final second = await coordinator.setLiked(
      post: _post(),
      userId: 'viewer',
      targetLiked: true,
      mutate: mutate,
      onOptimistic: (_) {},
      onRollback: (_) {},
      onReconciled: (_) {},
    );

    expect(second.status, PostInteractionStatus.alreadyPending);
    expect(coordinator.isPending('post-1'), isTrue);
    expect(mutationCalls, 1);
    completer.complete(const Right(null));
    final firstResult = await first;
    expect(firstResult.status, PostInteractionStatus.applied);
    expect(firstResult.post.likesCount, 3);
    expect(coordinator.isPending('post-1'), isFalse);
  });

  test('failed mutation rolls back with a generalized message', () async {
    Post? optimistic;
    Post? rollback;
    final result = await coordinator.setLiked(
      post: _post(),
      userId: 'viewer',
      targetLiked: true,
      mutate: () async => const Left(
        ServerFailure(message: 'private sentinel'),
      ),
      onOptimistic: (post) => optimistic = post,
      onRollback: (post) => rollback = post,
      onReconciled: (_) {},
    );

    expect(optimistic?.likesCount, 3);
    expect(rollback, _post());
    expect(result.status, PostInteractionStatus.rejected);
    expect(result.message, isNot(contains('private sentinel')));
  });

  test('timed out reconciliation keeps success and releases the pending lock',
      () async {
    final neverPost = Completer<Either<Failure, Post>>();
    final neverLiked = Completer<Either<Failure, bool>>();
    when(() => repository.getPost('post-1'))
        .thenAnswer((_) => neverPost.future);
    when(() => repository.isPostLiked('post-1', 'viewer'))
        .thenAnswer((_) => neverLiked.future);
    coordinator = PostInteractionCoordinator(
      repository: repository,
      reconciliationTimeout: const Duration(milliseconds: 10),
    );

    Post? reconciled;
    final result = await coordinator.setLiked(
      post: _post(),
      userId: 'viewer',
      targetLiked: true,
      mutate: () async => const Right(null),
      onOptimistic: (_) {},
      onRollback: (_) {},
      onReconciled: (post) => reconciled = post,
    );

    expect(result.status, PostInteractionStatus.applied);
    expect(result.post.likesCount, 3);
    expect(reconciled?.likesCount, 3);
    expect(coordinator.isPending('post-1'), isFalse);
  });
}
