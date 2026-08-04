import 'dart:async';
import 'dart:developer' as dev;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../../../core/services/content_filter.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../core/error/error_messages.dart';
import '../../../../core/utils/public_ai_text.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../emotion/domain/repositories/emotion_repository.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/saved_posts_page.dart';
import '../../domain/repositories/social_repository.dart';
import '../bloc/comment_bloc.dart';
import '../bloc/comment_event.dart';
import '../bloc/comment_state.dart';
import '../utils/saved_posts_change_notifier.dart';
import '../widgets/collection_picker_sheet.dart';
import '../widgets/comment_composer.dart';
import '../widgets/comment_list_item.dart';
import '../widgets/edit_post_bottom_sheet.dart';
import '../widgets/likes_bottom_sheet.dart';
import '../widgets/social_content_report_sheet.dart';
import '../widgets/social_user_actions_sheet.dart';

enum _PostLoadStatus { loading, loaded, error, notFound }

enum _PostDetailMenuAction { edit, delete, report, userActions }

class PostDetailPage extends StatefulWidget {
  final String postId;
  final SocialRepository? repository;
  final CommentBloc? commentBloc;
  final String? currentUserId;
  final SavedPostsChangeNotifier? savedPostsNotifier;
  final ValueNotifier<bool>? commentMutationNotifier;

  const PostDetailPage({
    super.key,
    required this.postId,
    this.repository,
    this.commentBloc,
    this.currentUserId,
    this.savedPostsNotifier,
    this.commentMutationNotifier,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _composerKey = GlobalKey();
  final _scrollController = ScrollController();
  Map<String, dynamic>? _post;
  late final SocialRepository _repository;
  _PostLoadStatus _postStatus = _PostLoadStatus.loading;

  bool _isLiked = false;
  bool _isSaved = false;
  bool _isSavePending = false;
  int _likesCount = 0;
  bool _isLikePending = false;
  bool _showLikeHeart = false;
  Timer? _likeHeartTimer;

  // 답글 상태
  String? _replyToCommentId;
  String? _replyToAuthorName;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? di.sl<SocialRepository>();
    _scrollController.addListener(_onScroll);
    _loadPost();
  }

  @override
  void dispose() {
    _likeHeartTimer?.cancel();
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _currentUserId {
    final injected = widget.currentUserId;
    if (injected != null && injected.isNotEmpty) return injected;
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) return authState.user.id;
    } catch (_) {
      // Tests and isolated embeds may intentionally omit AuthBloc.
    }
    return '';
  }

  SavedPostsChangeNotifier get _savedPostsNotifier =>
      widget.savedPostsNotifier ?? SavedPostsChangeNotifier.instance;

  Future<void> _loadPost() async {
    setState(() => _postStatus = _PostLoadStatus.loading);
    final myId = _currentUserId;

    try {
      final detailResult = await _repository.getPostDetail(widget.postId);
      if (detailResult.isLeft()) {
        if (mounted) setState(() => _postStatus = _PostLoadStatus.error);
        return;
      }
      final res = detailResult.fold<Map<String, dynamic>?>(
        (_) => null,
        (value) => value,
      );
      if (res == null) {
        if (mounted) setState(() => _postStatus = _PostLoadStatus.notFound);
        return;
      }

      bool liked = false;
      bool saved = false;
      if (myId.isNotEmpty) {
        final likedResult = await _repository.isPostLiked(widget.postId, myId);
        liked = likedResult.fold((_) => false, (v) => v);
        final savedResult = await _repository.isPostSaved(widget.postId, myId);
        saved = savedResult.fold((_) => false, (v) => v);
      }

      if (mounted) {
        setState(() {
          _post = res;
          _postStatus = _PostLoadStatus.loaded;
          _isLiked = liked;
          _isSaved = saved;
          _likesCount = (res['likes_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {
      dev.log('게시글 로드 실패', name: 'PostDetailPage');
      if (mounted) setState(() => _postStatus = _PostLoadStatus.error);
    }
  }

  Future<void> _toggleLike() async {
    final myId = _currentUserId;
    if (myId.isEmpty || _isLikePending) return;

    HapticFeedback.lightImpact();
    final wasLiked = _isLiked;
    final previousCount = _likesCount;
    setState(() {
      _isLikePending = true;
      _isLiked = !wasLiked;
      _likesCount = wasLiked
          ? (_likesCount - 1).clamp(0, 0x7fffffff).toInt()
          : _likesCount + 1;
    });

    final result = wasLiked
        ? await _repository.unlikePost(widget.postId, myId)
        : await _repository.likePost(widget.postId, myId);
    if (!mounted) return;
    if (result.isLeft()) {
      setState(() {
        _isLikePending = false;
        _isLiked = wasLiked;
        _likesCount = previousCount;
      });
      _showSafeMessage('좋아요를 반영하지 못했어요. 잠시 후 다시 시도해주세요.');
      return;
    }

    int? serverCount;
    bool? serverLiked;
    try {
      final detailResult = await _repository.getPostDetail(widget.postId);
      final likedResult = await _repository.isPostLiked(widget.postId, myId);
      serverCount = detailResult.fold<int?>(
        (_) => null,
        (detail) => (detail?['likes_count'] as num?)?.toInt(),
      );
      serverLiked = likedResult.fold<bool?>((_) => null, (liked) => liked);
    } catch (_) {
      dev.log('좋아요 상태 재조정 실패', name: 'PostDetailPage');
    }
    if (!mounted) return;
    setState(() {
      _isLikePending = false;
      if (serverCount != null) {
        _likesCount = serverCount.clamp(0, 0x7fffffff).toInt();
      }
      if (serverLiked != null) _isLiked = serverLiked;
    });
  }

  void _handleMediaDoubleTap() {
    if (!_isLiked && !_isLikePending) {
      _toggleLike();
    }
    _likeHeartTimer?.cancel();
    setState(() => _showLikeHeart = true);
    _likeHeartTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showLikeHeart = false);
    });
  }

  void _openLikes() {
    LikesBottomSheet.show(
      context,
      postId: widget.postId,
      currentUserId: _currentUserId,
      likeCount: _likesCount,
      repository: _repository,
    );
  }

  Future<void> _toggleSave() async {
    final myId = _currentUserId;
    if (myId.isEmpty || _isSavePending) return;
    final postId = widget.postId;
    final notifier = _savedPostsNotifier;

    HapticFeedback.lightImpact();
    final wasSaved = _isSaved;
    setState(() => _isSavePending = true);

    SavedPostLocation? previousLocation;
    if (wasSaved) {
      final locationResult = await _repository.getSavedPostLocation(
        postId: postId,
        userId: myId,
      );
      if (!mounted) return;
      if (locationResult.isLeft()) {
        setState(() => _isSavePending = false);
        _showSafeMessage('저장 위치를 확인하지 못했어요. 잠시 후 다시 시도해주세요.');
        return;
      }
      previousLocation = locationResult.fold<SavedPostLocation?>(
        (_) => null,
        (value) => value,
      );
      if (previousLocation == null) {
        setState(() {
          _isSavePending = false;
          _isSaved = false;
        });
        return;
      }
    }

    final result = wasSaved
        ? await _repository.unsavePost(postId, myId)
        : await _repository.savePost(postId, myId);
    if (result.isLeft()) {
      if (!mounted) return;
      setState(() {
        _isSavePending = false;
        _isSaved = wasSaved;
      });
      _showSafeMessage(
        wasSaved
            ? '저장 취소를 반영하지 못했어요. 잠시 후 다시 시도해주세요.'
            : '게시물을 저장하지 못했어요. 잠시 후 다시 시도해주세요.',
      );
      return;
    }

    notifier.publish(
      type:
          wasSaved ? SavedPostsChangeType.unsaved : SavedPostsChangeType.saved,
      postId: postId,
      wasSaved: wasSaved,
      isSaved: !wasSaved,
      oldCollectionId: previousLocation?.collectionId,
      newCollectionId: null,
    );
    if (!mounted) return;
    setState(() {
      _isSavePending = false;
      _isSaved = !wasSaved;
    });
    if (!wasSaved) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('게시물을 저장했어요'),
            action: SnackBarAction(
              label: '컬렉션 선택',
              onPressed: _openCollectionPicker,
            ),
          ),
        );
    }
  }

  Future<void> _openCollectionPicker() async {
    final myId = _currentUserId;
    if (!_isSaved || _isSavePending || myId.isEmpty || !mounted) return;
    await CollectionPickerSheet.show(
      context,
      postId: widget.postId,
      userId: myId,
      repository: _repository,
      changeNotifier: _savedPostsNotifier,
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset >= max * 0.9) {
      context.read<CommentBloc>().add(LoadMoreComments(postId: widget.postId));
    }
  }

  void _submitComment(BuildContext ctx) {
    final commentState = ctx.read<CommentBloc>().state;
    if (commentState is CommentLoaded && commentState.isSubmitting) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    if (ContentFilter.hasBannedKeyword(content)) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('커뮤니티 가이드라인에 어긋나는 표현이 포함되어 있습니다.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    final authState = ctx.read<AuthBloc>().state;
    final senderName =
        authState is AuthAuthenticated ? authState.user.displayName : '사용자';

    if (_replyToCommentId != null) {
      ctx.read<CommentBloc>().add(
            CreateReplyRequested(
              postId: widget.postId,
              parentId: _replyToCommentId!,
              content: content,
              postAuthorId: _post?['author_id'] as String?,
              senderName: senderName,
            ),
          );
    } else {
      ctx.read<CommentBloc>().add(
            CreateCommentRequested(
              postId: widget.postId,
              content: content,
              postAuthorId: _post?['author_id'] as String?,
              senderName: senderName,
            ),
          );
    }
  }

  void _showReplyInput(String commentId, String authorName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToAuthorName = authorName;
    });
    _commentController.clear();
    _focusComposer();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToAuthorName = null;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  void _focusComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _commentFocusNode.requestFocus();
      final composerContext = _composerKey.currentContext;
      if (composerContext != null) {
        Scrollable.ensureVisible(
          composerContext,
          duration: const Duration(milliseconds: 180),
          alignment: 1,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final injectedBloc = widget.commentBloc;
    if (injectedBloc != null) {
      return BlocProvider<CommentBloc>.value(
        value: injectedBloc,
        child: _buildScaffold(),
      );
    }
    return BlocProvider(
      create: (_) => CommentBloc(
        getComments: di.sl(),
        createComment: di.sl(),
        deleteComment: di.sl(),
        updateComment: di.sl(),
        currentUserId: _currentUserId,
        socialRepository: _repository,
      )..add(LoadComments(postId: widget.postId)),
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          '게시글',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<_PostDetailMenuAction>(
            key: const Key('post_detail_options'),
            enabled: _post != null,
            tooltip: '게시물 옵션',
            onSelected: _handlePostOption,
            itemBuilder: (_) {
              final isOwner = _post?['author_id'] == _currentUserId;
              if (isOwner) {
                return const [
                  PopupMenuItem(
                    value: _PostDetailMenuAction.edit,
                    child: Text('수정'),
                  ),
                  PopupMenuItem(
                    value: _PostDetailMenuAction.delete,
                    child: Text('삭제'),
                  ),
                ];
              }
              return const [
                PopupMenuItem(
                  value: _PostDetailMenuAction.report,
                  child: Text('게시물 신고'),
                ),
                PopupMenuItem(
                  value: _PostDetailMenuAction.userActions,
                  child: Text('사용자 신고 · 차단'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<CommentBloc, CommentState>(
              listenWhen: (previous, current) {
                if (current is CommentError && previous != current) return true;
                if (current is! CommentLoaded ||
                    current.actionOutcome == null) {
                  return false;
                }
                if (previous is CommentError &&
                    current.actionOutcome?.succeeded == false) {
                  return false;
                }
                final previousOutcome =
                    previous is CommentLoaded ? previous.actionOutcome : null;
                return previousOutcome != current.actionOutcome;
              },
              listener: (context, state) {
                if (state is CommentError) {
                  _showSafeMessage(state.message);
                  return;
                }
                if (state is CommentLoaded && state.actionOutcome != null) {
                  final outcome = state.actionOutcome!;
                  if (!outcome.succeeded) {
                    _showSafeMessage(
                      outcome.message ?? '요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요.',
                    );
                    return;
                  }
                  if (outcome.kind == CommentActionKind.commentCreated ||
                      outcome.kind == CommentActionKind.replyCreated ||
                      outcome.kind == CommentActionKind.commentDeleted ||
                      outcome.kind == CommentActionKind.replyDeleted) {
                    widget.commentMutationNotifier?.value = true;
                  }
                  if (outcome.kind == CommentActionKind.commentCreated ||
                      outcome.kind == CommentActionKind.replyCreated) {
                    _commentController.clear();
                    setState(() {
                      _replyToCommentId = null;
                      _replyToAuthorName = null;
                    });
                    FocusScope.of(context).unfocus();
                  }
                }
              },
              builder: (context, state) => CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _buildPostBody(state)),
                  SliverToBoxAdapter(child: _buildCommentHeader(state)),
                  if (state is CommentLoaded && state.comments.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyComments()),
                  if (state is CommentLoading || state is CommentInitial)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.h),
                          child: const CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  if (state is CommentError)
                    SliverToBoxAdapter(child: _buildCommentLoadError()),
                  if (state is CommentLoaded)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        if (i == state.comments.length) {
                          return _buildCommentFooter(state);
                        }
                        final comment = state.comments[i];
                        final myId = _currentUserId;
                        return CommentListItem(
                          comment: comment,
                          currentUserId: myId,
                          postAuthorId: _post?['author_id'] as String? ?? '',
                          onDelete: comment.authorId == myId
                              ? () => context.read<CommentBloc>().add(
                                    DeleteCommentRequested(
                                        commentId: comment.id),
                                  )
                              : null,
                          onReplyTo: _showReplyInput,
                          onReport: _reportComment,
                          pendingLikeIds: state.pendingLikeIds,
                          pendingDeleteIds: state.pendingDeleteIds,
                        );
                      }, childCount: state.comments.length + 1),
                    ),
                ],
              ),
            ),
          ),
          Builder(builder: (ctx) => _buildCommentInput(ctx)),
        ],
      ),
    );
  }

  Widget _buildPostBody(CommentState commentState) {
    if (_postStatus == _PostLoadStatus.loading) {
      return SizedBox(
        height: 220.h,
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: const CommentShimmerLoading(),
        ),
      );
    }
    if (_postStatus == _PostLoadStatus.error) {
      return _buildPostState(
        key: const Key('post_detail_error'),
        icon: Icons.cloud_off_outlined,
        title: '게시글을 불러오지 못했어요',
        description: '연결 상태를 확인하고 다시 시도해주세요.',
        actionLabel: '다시 시도',
        onAction: _loadPost,
      );
    }
    if (_postStatus == _PostLoadStatus.notFound) {
      return _buildPostState(
        key: const Key('post_detail_not_found'),
        icon: Icons.find_in_page_outlined,
        title: '게시글을 찾을 수 없어요',
        description: '삭제되었거나 더 이상 볼 수 없는 게시글이에요.',
      );
    }
    if (_post == null) return const SizedBox.shrink();

    final user = _post!['users'] as Map<String, dynamic>?;
    final authorId = _post!['author_id'] as String? ?? '';
    final authorName = user?['display_name'] as String? ?? '알 수 없음';
    final photoUrl = user?['photo_url'] as String?;
    final content = publicAiText(_post!['caption'] as String? ?? '');
    // image_urls 배열 우선, 없으면 image_url 단일 필드 폴백
    final rawUrls = _post!['image_urls'];
    final List<String> imageUrls =
        rawUrls != null && (rawUrls as List).isNotEmpty
            ? List<String>.from(rawUrls)
            : (_post!['image_url'] as String?) != null
                ? [_post!['image_url'] as String]
                : [];
    final createdAt = _post!['created_at'] as String? ?? '';
    final commentsCount = _commentTotalCount(commentState);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('post_detail_author'),
            onTap: authorId.isEmpty
                ? null
                : () => context.push('/user-profile/$authorId'),
            borderRadius: BorderRadius.circular(10.r),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  // 아바타 폴백: 발바닥 아이콘 + 연블루 배경 (사람 아이콘 금지)
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: AppTheme.tilePastelBlue,
                    backgroundImage: photoUrl != null
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                    child: photoUrl == null
                        ? Icon(
                            Icons.pets,
                            size: 20.w,
                            color: AppTheme.primaryColor,
                          )
                        : null,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _timeAgo(createdAt),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (imageUrls.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _MultiImageCarousel(
              imageUrls: imageUrls,
              onDoubleTap: _handleMediaDoubleTap,
              showHeart: _showLikeHeart,
            ),
          ],
          if (content.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(content, style: TextStyle(fontSize: 14.sp, height: 1.6)),
          ],
          // 감정 분석 컨텍스트 카드 (emotion 타입 게시물)
          _buildEmotionContextCard(),
          SizedBox(height: 12.h),
          Row(
            children: [
              Semantics(
                button: true,
                label: _isLiked ? '게시글 좋아요 취소' : '게시글 좋아요',
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    key: const Key('post_detail_like_button'),
                    onPressed: _isLikePending ? null : _toggleLike,
                    icon: _isLikePending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 20.w,
                            color: _isLiked
                                ? AppTheme.highlightColor
                                : AppTheme.secondaryTextColor,
                          ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: '좋아요 $_likesCount명 보기',
                child: SizedBox(
                  height: 44,
                  child: TextButton(
                    key: const Key('post_detail_likes_count'),
                    onPressed: _openLikes,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: AppTheme.secondaryTextColor,
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                    ),
                    child: Text(
                      '$_likesCount',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: TextButton.icon(
                  key: const Key('post_detail_comment_action'),
                  onPressed: _focusComposer,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: AppTheme.secondaryTextColor,
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                  ),
                  icon: Icon(Icons.chat_bubble_outline, size: 20.w),
                  label: Text(
                    '$commentsCount',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  key: const Key('post_detail_share_button'),
                  onPressed: _sharePost,
                  tooltip: '게시글 공유',
                  icon: Icon(Icons.share_outlined, size: 20.w),
                ),
              ),
              const Spacer(),
              if (_isSaved)
                TextButton.icon(
                  key: const Key('post_detail_collection_button'),
                  onPressed: _isSavePending ? null : _openCollectionPicker,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                  ),
                  icon: Icon(Icons.folder_outlined, size: 18.w),
                  label: Text('컬렉션 변경', style: TextStyle(fontSize: 12.sp)),
                ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  key: const Key('post_detail_save_button'),
                  onPressed: _isSavePending ? null : _toggleSave,
                  tooltip: _isSaved ? '저장 취소' : '게시글 저장',
                  icon: _isSavePending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          size: 20.w,
                          color: _isSaved
                              ? AppTheme.primaryColor
                              : AppTheme.secondaryTextColor,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionContextCard() {
    final rawEmotion = _post?['emotion_analysis'];
    final petId = _post?['pet_id'] as String?;
    if (rawEmotion == null || petId == null) return const SizedBox.shrink();

    final emotion =
        rawEmotion is Map<String, dynamic> ? rawEmotion : <String, dynamic>{};
    final numEntries = emotion.entries.where((e) => e.value is num).toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    if (numEntries.isEmpty) return const SizedBox.shrink();

    final dominant = numEntries.first;

    final label = AppTheme.getEmotionLabel(dominant.key);
    final petName = _post?['pet_name'] as String? ?? '우리 아이';

    const cardColor = AppTheme.featurePlay; // v2-review: 7B4FE5 근사

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: cardColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 14.sp, color: cardColor),
              SizedBox(width: 6.w),
              Text(
                '이 사진의 AI 감정분석',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: cardColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                AppTheme.getEmotionIcon(dominant.key),
                size: 28.sp,
                color: AppTheme.getEmotionColor(dominant.key),
              ),
              SizedBox(width: 8.w),
              // 감정 라벨만 — 퍼센트 수치 노출 금지 (P0 정책, 수치는 데이터만 보존)
              Text(
                label,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          FutureBuilder<String?>(
            future: _getComparisonInsight(
              petId,
              dominant.key,
              dominant.value as num,
            ),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text(
                  snap.data!,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () => context.push(
              '/emotion-timeline',
              extra: {'petId': petId, 'petName': petName},
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '전체 추이 보기',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: cardColor,
                  ),
                ),
                Icon(Icons.chevron_right, size: 14.w, color: cardColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getComparisonInsight(
    String petId,
    String emotion,
    num value,
  ) async {
    final result = await di.sl<EmotionRepository>().getEmotionComparisonInsight(
          petId: petId,
          emotion: emotion,
          value: value,
        );
    return result.fold((_) => null, (insight) => insight);
  }

  Widget _buildCommentHeader(CommentState state) {
    final count = _commentTotalCount(state);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: AppTheme.subtleBackground,
      child: Text(
        '댓글 $count개',
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
      ),
    );
  }

  int _commentTotalCount(CommentState state) {
    if (state is CommentLoaded) return state.totalCount;
    return (_post?['comments_count'] as num?)?.toInt() ?? 0;
  }

  Widget _buildPostState({
    required Key key,
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44.w, color: AppTheme.lightTextColor),
          SizedBox(height: 12.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 16.h),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentLoadError() {
    return Padding(
      key: const Key('post_comments_error'),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40.w,
            color: AppTheme.lightTextColor,
          ),
          SizedBox(height: 10.h),
          const Text('댓글을 불러오지 못했어요'),
          SizedBox(height: 12.h),
          OutlinedButton(
            key: const Key('post_comments_retry'),
            onPressed: () => context.read<CommentBloc>().add(
                  LoadComments(postId: widget.postId),
                ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentFooter(CommentLoaded state) {
    if (state.isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.error != null) {
      return Center(
        child: TextButton.icon(
          key: const Key('post_comments_load_more_retry'),
          onPressed: () => context.read<CommentBloc>().add(
                LoadMoreComments(postId: widget.postId),
              ),
          icon: const Icon(Icons.refresh),
          label: const Text('댓글 더 불러오기'),
        ),
      );
    }
    return const SizedBox(height: 12);
  }

  Widget _buildEmptyComments() => Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '아직 댓글이 없어요',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '첫 댓글을 작성해보세요',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.secondaryTextColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );

  Widget _buildCommentInput(BuildContext ctx) {
    final state = ctx.watch<CommentBloc>().state;
    final isSubmitting = state is CommentLoaded && state.isSubmitting;
    return CommentComposer(
      key: _composerKey,
      controller: _commentController,
      focusNode: _commentFocusNode,
      isSubmitting: isSubmitting,
      replyAuthorName: _replyToAuthorName,
      onSend: () => _submitComment(ctx),
      onCancelReply: _cancelReply,
      inputKey: const Key('post_comment_input'),
      sendKey: const Key('post_comment_send'),
      replyTargetKey: const Key('post_comment_reply_target'),
      replyCancelKey: const Key('post_comment_reply_cancel'),
    );
  }

  void _handlePostOption(_PostDetailMenuAction action) {
    switch (action) {
      case _PostDetailMenuAction.edit:
        unawaited(_editPost());
        return;
      case _PostDetailMenuAction.delete:
        unawaited(_deletePost());
        return;
      case _PostDetailMenuAction.report:
        unawaited(_reportPost());
        return;
      case _PostDetailMenuAction.userActions:
        unawaited(_showAuthorActions());
        return;
    }
  }

  Future<void> _editPost() async {
    final result = await _repository.getPost(widget.postId);
    if (!mounted) return;
    await result.fold((_) async => _showSafeMessage('게시물을 수정할 준비를 하지 못했어요.'), (
      post,
    ) async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EditPostBottomSheet(
          post: post,
          onSave: (updatedPost) => unawaited(_saveEditedPost(updatedPost)),
        ),
      );
    });
  }

  Future<void> _saveEditedPost(Post updatedPost) async {
    final result = await _repository.updatePost(updatedPost);
    if (!mounted) return;
    result.fold((_) => _showSafeMessage('게시물을 수정하지 못했어요. 잠시 후 다시 시도해주세요.'), (
      _,
    ) {
      _showSafeMessage('게시물이 수정되었습니다.');
      unawaited(_loadPost());
    });
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('이 게시물을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _repository.deletePost(widget.postId);
    if (!mounted) return;
    result.fold(
      (_) => _showSafeMessage('게시물을 삭제하지 못했어요. 잠시 후 다시 시도해주세요.'),
      (_) => Navigator.of(context).pop(true),
    );
  }

  Future<void> _reportPost() async {
    final accepted = await SocialContentReportSheet.show(
      context,
      target: SocialReportTarget.post,
      targetId: widget.postId,
      currentUserId: _currentUserId,
      repository: _repository,
    );
    if (accepted && mounted) _showSafeMessage('신고가 접수되었습니다.');
  }

  Future<void> _reportComment(Comment comment) async {
    final accepted = await SocialContentReportSheet.show(
      context,
      target: SocialReportTarget.comment,
      targetId: comment.id,
      currentUserId: _currentUserId,
      repository: _repository,
    );
    if (accepted && mounted) _showSafeMessage('신고가 접수되었습니다.');
  }

  Future<void> _showAuthorActions() async {
    final authorId = _post?['author_id'] as String? ?? '';
    if (authorId.isEmpty) return;
    final user = _post?['users'] as Map<String, dynamic>?;
    final authorName = user?['display_name'] as String? ?? '이 사용자';
    await SocialUserActionsSheet.show(
      context,
      targetUserId: authorId,
      targetUserName: authorName,
      currentUserId: _currentUserId,
      repository: _repository,
      onBlocked: () {
        if (mounted) Navigator.of(context).pop(true);
      },
    );
  }

  Future<void> _sharePost() async {
    final caption = publicAiText(_post?['caption'] as String? ?? '');
    final preview =
        caption.length > 100 ? '${caption.substring(0, 100)}...' : caption;
    final text = preview.isEmpty
        ? 'PetSpace에서 게시물을 확인해보세요.'
        : '$preview\n\nPetSpace에서 게시물을 확인해보세요.';
    await Share.share(text);
  }

  void _showSafeMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(publicErrorMessage(message)),
        ),
      );
  }

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}

// ─── 멀티 이미지 캐러셀 ────────────────────────────────────────────────────────
class _MultiImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final VoidCallback onDoubleTap;
  final bool showHeart;

  const _MultiImageCarousel({
    required this.imageUrls,
    required this.onDoubleTap,
    required this.showHeart,
  });

  @override
  State<_MultiImageCarousel> createState() => _MultiImageCarouselState();
}

class _MultiImageCarouselState extends State<_MultiImageCarousel> {
  int _current = 0;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.imageUrls.length;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: SizedBox(
            height: 280.h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, i) => GestureDetector(
                    key: Key('post_detail_media_$i'),
                    onDoubleTap: widget.onDoubleTap,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[i],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppTheme.subtleBackground),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.subtleBackground,
                        child: Icon(
                          Icons.broken_image,
                          size: 48.w,
                          color: AppTheme.hintColor,
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    key: const Key('post_detail_double_tap_heart'),
                    opacity: widget.showHeart ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedScale(
                      scale: widget.showHeart ? 1 : 0.4,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 80.w,
                        shadows: const [
                          Shadow(color: Colors.black26, blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (count > 1) ...[
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: _current == i ? 16.w : 6.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color:
                      _current == i ? AppTheme.primaryColor : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3.r),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
