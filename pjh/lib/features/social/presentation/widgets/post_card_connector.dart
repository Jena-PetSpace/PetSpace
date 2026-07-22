import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../core/utils/public_ai_text.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/social_repository.dart';
import '../controllers/post_interaction_coordinator.dart';
import 'comments_bottom_sheet.dart';
import 'post_card.dart';

typedef PostChangedCallback = void Function(Post post);
typedef PostRemovedCallback = void Function(String postId);

/// Wires a stateless surface-owned [Post] to the shared interaction pipeline.
class PostCardConnector extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final PostChangedCallback onPostChanged;
  final PostRemovedCallback onPostRemoved;
  final SocialRepository? repository;
  final PostInteractionCoordinator? coordinator;
  final CommentBlocFactory? commentBlocFactory;
  final Future<bool> Function()? commentsLauncher;
  final Future<bool?> Function()? detailLauncher;
  final Future<void> Function(String text)? shareHandler;
  final Future<bool> Function(Post post)? deleteHandler;
  final VoidCallback? onLikeRequested;
  final VoidCallback? onDeleteRequested;
  final VoidCallback? onEdit;
  final void Function(String hashtag)? onHashtagTap;
  final String? shareText;

  const PostCardConnector({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onPostChanged,
    required this.onPostRemoved,
    this.repository,
    this.coordinator,
    this.commentBlocFactory,
    this.commentsLauncher,
    this.detailLauncher,
    this.shareHandler,
    this.deleteHandler,
    this.onLikeRequested,
    this.onDeleteRequested,
    this.onEdit,
    this.onHashtagTap,
    this.shareText,
  });

  @override
  State<PostCardConnector> createState() => _PostCardConnectorState();
}

class _PostCardConnectorState extends State<PostCardConnector> {
  late Post _post;

  SocialRepository get _repository =>
      widget.repository ?? di.sl<SocialRepository>();
  PostInteractionCoordinator get _coordinator =>
      widget.coordinator ?? di.sl<PostInteractionCoordinator>();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(PostCardConnector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) _post = widget.post;
  }

  void _apply(Post post) {
    if (!mounted || post.id != _post.id) return;
    setState(() => _post = post);
    widget.onPostChanged(post);
  }

  Future<void> _toggleLike() async {
    if (widget.onLikeRequested != null) {
      widget.onLikeRequested!();
      return;
    }
    if (widget.currentUserId.isEmpty) return;
    final targetLiked = !_post.isLikedByCurrentUser;
    final result = await _coordinator.setLiked(
      post: _post,
      userId: widget.currentUserId,
      targetLiked: targetLiked,
      mutate: () => targetLiked
          ? _repository.likePost(_post.id, widget.currentUserId)
          : _repository.unlikePost(_post.id, widget.currentUserId),
      onOptimistic: _apply,
      onRollback: _apply,
      onReconciled: _apply,
    );
    if (!mounted ||
        result.status != PostInteractionStatus.rejected ||
        result.message == null) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message!)));
  }

  Future<void> _openComments() async {
    final bool changed;
    if (widget.commentsLauncher != null) {
      changed = await widget.commentsLauncher!();
    } else {
      changed = await CommentsBottomSheet.show(
        context: context,
        postId: _post.id,
        postAuthorId: _post.authorId,
        currentUserId: widget.currentUserId,
        repository: _repository,
        commentBlocFactory: widget.commentBlocFactory,
        onPostRemoved: () => widget.onPostRemoved(_post.id),
      );
    }
    if (!changed || !mounted || !context.mounted) return;
    final result = await _repository.getPost(_post.id);
    if (!mounted) return;
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 수를 새로고침하지 못했어요.')),
      ),
      _apply,
    );
  }

  Future<void> _openPostDetail() async {
    final bool? removed;
    if (widget.detailLauncher != null) {
      removed = await widget.detailLauncher!();
    } else {
      removed = await context.push<bool>('/post/${_post.id}');
    }
    if (!mounted) return;
    if (removed == true) {
      widget.onPostRemoved(_post.id);
      return;
    }
    await _reconcileAfterDetail();
  }

  Future<void> _reconcileAfterDetail() async {
    var next = _post;
    var changed = false;
    var hadFailure = false;

    final postResult = await _repository.getPost(_post.id);
    if (!mounted) return;
    postResult.fold(
      (_) => hadFailure = true,
      (serverPost) {
        next = serverPost.copyWith(
          isLikedByCurrentUser: next.isLikedByCurrentUser,
          isSavedByCurrentUser: next.isSavedByCurrentUser,
        );
        changed = true;
      },
    );

    if (widget.currentUserId.isNotEmpty) {
      final likedResult = await _repository.isPostLiked(
        _post.id,
        widget.currentUserId,
      );
      if (!mounted) return;
      likedResult.fold(
        (_) => hadFailure = true,
        (liked) {
          next = next.copyWith(isLikedByCurrentUser: liked);
          changed = true;
        },
      );

      final savedResult = await _repository.isPostSaved(
        _post.id,
        widget.currentUserId,
      );
      if (!mounted) return;
      savedResult.fold(
        (_) => hadFailure = true,
        (saved) {
          next = next.copyWith(isSavedByCurrentUser: saved);
          changed = true;
        },
      );
    }

    if (changed) _apply(next);
    if (hadFailure && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('게시글 상태 일부를 새로고침하지 못했어요.'),
          ),
        );
    }
  }

  Future<void> _share() async {
    final content = widget.shareText ?? _defaultShareText(_post);
    if (widget.shareHandler != null) {
      await widget.shareHandler!(content);
    } else {
      await Share.share(content);
    }
  }

  String _defaultShareText(Post post) {
    final caption = publicAiText(post.content ?? '');
    final preview =
        caption.length > 100 ? '${caption.substring(0, 100)}...' : caption;
    return preview.isEmpty
        ? 'PetSpace에서 게시물을 확인해보세요.'
        : '$preview\n\nPetSpace에서 게시물을 확인해보세요.';
  }

  Future<void> _delete() async {
    if (widget.onDeleteRequested != null) {
      widget.onDeleteRequested!();
      return;
    }
    final succeeded = widget.deleteHandler != null
        ? await widget.deleteHandler!(_post)
        : (await _repository.deletePost(_post.id)).isRight();
    if (!mounted) return;
    if (succeeded) {
      widget.onPostRemoved(_post.id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시물을 삭제하지 못했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PostCard(
      post: _post,
      currentUserId: widget.currentUserId,
      repository: _repository,
      onLike: () => unawaited(_toggleLike()),
      onComment: () => unawaited(_openComments()),
      onShare: () => unawaited(_share()),
      onOpenDetail: () => unawaited(_openPostDetail()),
      onEdit: widget.onEdit,
      onDelete: () => unawaited(_delete()),
      onBlocked: () => widget.onPostRemoved(_post.id),
      onHashtagTap: widget.onHashtagTap,
    );
  }
}
