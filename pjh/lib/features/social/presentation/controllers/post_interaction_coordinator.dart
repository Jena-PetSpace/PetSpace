import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';

enum PostInteractionStatus {
  applied,
  rejected,
  alreadyPending,
  unchanged,
}

class PostInteractionResult {
  final PostInteractionStatus status;
  final Post post;
  final String? message;

  const PostInteractionResult({
    required this.status,
    required this.post,
    this.message,
  });

  bool get succeeded => status == PostInteractionStatus.applied;
}

typedef PostLikeMutation = Future<Either<Failure, void>> Function();
typedef PostStateCallback = void Function(Post post);

/// Shares only mutation coordination. Screens and BLoCs continue to own lists.
class PostInteractionCoordinator {
  final SocialRepository _repository;
  final Duration _reconciliationTimeout;
  final Set<String> _pendingPostIds = <String>{};

  PostInteractionCoordinator({
    required SocialRepository repository,
    Duration reconciliationTimeout = const Duration(seconds: 8),
  })  : _repository = repository,
        _reconciliationTimeout = reconciliationTimeout;

  bool isPending(String postId) => _pendingPostIds.contains(postId);

  Future<PostInteractionResult> setLiked({
    required Post post,
    required String userId,
    required bool targetLiked,
    required PostLikeMutation mutate,
    required PostStateCallback onOptimistic,
    required PostStateCallback onRollback,
    required PostStateCallback onReconciled,
  }) async {
    if (userId.isEmpty || post.isLikedByCurrentUser == targetLiked) {
      return PostInteractionResult(
        status: PostInteractionStatus.unchanged,
        post: post,
      );
    }
    if (!_pendingPostIds.add(post.id)) {
      return PostInteractionResult(
        status: PostInteractionStatus.alreadyPending,
        post: post,
      );
    }

    final optimistic = post.copyWith(
      isLikedByCurrentUser: targetLiked,
      likesCount: targetLiked
          ? post.likesCount + 1
          : (post.likesCount - 1).clamp(0, 0x7fffffff).toInt(),
    );
    onOptimistic(optimistic);

    try {
      final result = await mutate();
      if (result.isLeft()) {
        onRollback(post);
        return PostInteractionResult(
          status: PostInteractionStatus.rejected,
          post: post,
          message: '좋아요를 반영하지 못했어요. 잠시 후 다시 시도해주세요.',
        );
      }

      var reconciled = optimistic;
      try {
        final results = await Future.wait([
          _repository.getPost(post.id),
          _repository.isPostLiked(post.id, userId),
        ]).timeout(_reconciliationTimeout);
        final serverPost = results[0].fold<Post?>((_) => null, (value) {
          return value as Post;
        });
        final serverLiked = results[1].fold<bool?>((_) => null, (value) {
          return value as bool;
        });
        reconciled = optimistic.copyWith(
          likesCount: (serverPost?.likesCount ?? optimistic.likesCount)
              .clamp(0, 0x7fffffff)
              .toInt(),
          isLikedByCurrentUser: serverLiked ?? optimistic.isLikedByCurrentUser,
        );
      } catch (_) {
        // A successful mutation remains optimistic when reconciliation fails.
      }
      onReconciled(reconciled);
      return PostInteractionResult(
        status: PostInteractionStatus.applied,
        post: reconciled,
      );
    } catch (_) {
      onRollback(post);
      return PostInteractionResult(
        status: PostInteractionStatus.rejected,
        post: post,
        message: '좋아요를 반영하지 못했어요. 잠시 후 다시 시도해주세요.',
      );
    } finally {
      _pendingPostIds.remove(post.id);
    }
  }
}
