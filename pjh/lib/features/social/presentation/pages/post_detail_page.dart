import 'dart:async';
import 'dart:developer' as dev;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../../../shared/widgets/shimmer_loading.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/comment_bloc.dart';
import '../bloc/comment_event.dart';
import '../bloc/comment_state.dart';
import '../widgets/comment_list_item.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  Map<String, dynamic>? _post;
  bool _postLoading = true;

  bool _isLiked = false;
  bool _isSaved = false;
  int _likesCount = 0;
  Timer? _likeDebounce;

  // 답글 상태
  String? _replyToCommentId;
  String? _replyToAuthorName;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPost();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _likeDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPost() async {
    try {
      final client = Supabase.instance.client;
      final myId = client.auth.currentUser?.id ?? '';

      final res = await client
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .eq('id', widget.postId)
          .maybeSingle();

      bool liked = false;
      bool saved = false;
      if (myId.isNotEmpty && res != null) {
        final likeRow = await client
            .from('likes')
            .select('id')
            .eq('post_id', widget.postId)
            .eq('user_id', myId)
            .maybeSingle();
        liked = likeRow != null;

        final savedRow = await client
            .from('saved_posts')
            .select('id')
            .eq('post_id', widget.postId)
            .eq('user_id', myId)
            .maybeSingle();
        saved = savedRow != null;
      }

      if (mounted) {
        setState(() {
          _post = res;
          _postLoading = false;
          _isLiked = liked;
          _isSaved = saved;
          _likesCount = res?['likes_count'] as int? ?? 0;
        });
      }
    } catch (e) {
      dev.log('게시글 로드 실패: $e', name: 'PostDetailPage');
      if (mounted) setState(() => _postLoading = false);
    }
  }

  void _toggleLike() {
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (myId.isEmpty) return;

    HapticFeedback.lightImpact();
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !wasLiked;
      _likesCount += wasLiked ? -1 : 1;
    });

    _likeDebounce?.cancel();
    _likeDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final client = Supabase.instance.client;
        if (!wasLiked) {
          await client.from('likes').upsert({
            'post_id': widget.postId,
            'user_id': myId,
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,post_id', ignoreDuplicates: true);
          await client.rpc('increment_post_likes',
              params: {'post_id': widget.postId});
        } else {
          final deleted = await client
              .from('likes')
              .delete()
              .eq('post_id', widget.postId)
              .eq('user_id', myId)
              .select();
          if (deleted.isNotEmpty) {
            await client.rpc('decrement_post_likes',
                params: {'post_id': widget.postId});
          }
        }
      } catch (e) {
        dev.log('좋아요 토글 실패: $e', name: 'PostDetailPage');
        if (mounted) {
          setState(() {
            _isLiked = wasLiked;
            _likesCount += wasLiked ? 1 : -1;
          });
        }
      }
    });
  }

  void _toggleSave() {
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (myId.isEmpty) return;

    HapticFeedback.lightImpact();
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);

    Future(() async {
      try {
        final client = Supabase.instance.client;
        if (!wasSaved) {
          await client.from('saved_posts').upsert({
            'post_id': widget.postId,
            'user_id': myId,
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id,post_id', ignoreDuplicates: true);
        } else {
          await client
              .from('saved_posts')
              .delete()
              .eq('post_id', widget.postId)
              .eq('user_id', myId);
        }
      } catch (e) {
        dev.log('저장 토글 실패: $e', name: 'PostDetailPage');
        if (mounted) setState(() => _isSaved = wasSaved);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset >= max * 0.9) {
      context.read<CommentBloc>().add(LoadMoreComments(postId: widget.postId));
    }
  }

  void _submitComment() {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final authState = context.read<AuthBloc>().state;
    final senderName =
        authState is AuthAuthenticated ? authState.user.displayName : '사용자';

    if (_replyToCommentId != null) {
      context.read<CommentBloc>().add(CreateReplyRequested(
            postId: widget.postId,
            parentCommentId: _replyToCommentId!,
            content: content,
            postAuthorId: _post?['author_id'] as String?,
            senderName: senderName,
          ));
      setState(() {
        _replyToCommentId = null;
        _replyToAuthorName = null;
      });
    } else {
      context.read<CommentBloc>().add(CreateCommentRequested(
            postId: widget.postId,
            content: content,
            postAuthorId: _post?['author_id'] as String?,
            senderName: senderName,
          ));
    }
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  void _showReplyInput(String commentId, String authorName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToAuthorName = authorName;
    });
    _commentController.clear();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToAuthorName = null;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CommentBloc(
        getComments: di.sl(),
        createComment: di.sl(),
        deleteComment: di.sl(),
        updateComment: di.sl(),
        currentUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      )..add(LoadComments(postId: widget.postId)),
      child: Scaffold(
        appBar: AppBar(
          title: Text('게시글',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Column(children: [
          Expanded(
            child: BlocConsumer<CommentBloc, CommentState>(
              listener: (context, state) {
                if (state is CommentError) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppTheme.errorColor));
                }
              },
              builder: (context, state) => CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _buildPostBody()),
                  SliverToBoxAdapter(child: _buildCommentHeader(state)),
                  if (state is CommentLoaded && state.comments.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyComments()),
                  if (state is CommentLoading)
                    const SliverToBoxAdapter(
                        child: Center(
                            child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator()))),
                  if (state is CommentLoaded)
                    SliverList(
                        delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        if (i == state.comments.length) {
                          return state.isLoadingMore
                              ? const Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator()))
                              : const SizedBox.shrink();
                        }
                        final comment = state.comments[i];
                        final myId =
                            Supabase.instance.client.auth.currentUser?.id ?? '';
                        return CommentListItem(
                          comment: comment,
                          currentUserId: myId,
                          onDelete: comment.authorId == myId
                              ? () => context.read<CommentBloc>().add(
                                  DeleteCommentRequested(commentId: comment.id))
                              : null,
                          onReply: () => _showReplyInput(
                              comment.id, comment.authorName),
                        );
                      },
                      childCount: state.comments.length + 1,
                    )),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ]),
      ),
    );
  }

  Widget _buildPostBody() {
    if (_postLoading) {
      return Padding(
          padding: EdgeInsets.all(24.w),
          child: const CommentShimmerLoading());
    }
    if (_post == null) return const SizedBox.shrink();

    final user = _post!['users'] as Map<String, dynamic>?;
    final authorName = user?['display_name'] as String? ?? '알 수 없음';
    final photoUrl = user?['photo_url'] as String?;
    final content = _post!['caption'] as String? ?? '';
    // image_urls 배열 우선, 없으면 image_url 단일 필드 폴백
    final rawUrls = _post!['image_urls'];
    final List<String> imageUrls = rawUrls != null && (rawUrls as List).isNotEmpty
        ? List<String>.from(rawUrls)
        : (_post!['image_url'] as String?) != null
            ? [_post!['image_url'] as String]
            : [];
    final createdAt = _post!['created_at'] as String? ?? '';
    final commentsCount = _post!['comments_count'] as int? ?? 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppTheme.dividerColor))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: AppTheme.subtleBackground,
            backgroundImage:
                photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
            child: photoUrl == null
                ? Icon(Icons.person, size: 20.w, color: AppTheme.hintColor)
                : null,
          ),
          SizedBox(width: 10.w),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(authorName,
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w600)),
                Text(_timeAgo(createdAt),
                    style: TextStyle(
                        fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
              ])),
        ]),
        if (imageUrls.isNotEmpty) ...[
          SizedBox(height: 12.h),
          _MultiImageCarousel(imageUrls: imageUrls),
        ],
        if (content.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Text(content, style: TextStyle(fontSize: 14.sp, height: 1.6))
        ],
        SizedBox(height: 12.h),
        Row(children: [
          GestureDetector(
            onTap: _toggleLike,
            child: Row(children: [
              Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                size: 20.w,
                color: _isLiked ? AppTheme.highlightColor : AppTheme.secondaryTextColor,
              ),
              SizedBox(width: 4.w),
              Text('$_likesCount',
                  style: TextStyle(
                      fontSize: 13.sp, color: AppTheme.secondaryTextColor)),
            ]),
          ),
          SizedBox(width: 12.w),
          Icon(Icons.chat_bubble_outline,
              size: 20.w, color: AppTheme.secondaryTextColor),
          SizedBox(width: 4.w),
          Text('$commentsCount',
              style: TextStyle(
                  fontSize: 13.sp, color: AppTheme.secondaryTextColor)),
          const Spacer(),
          GestureDetector(
            onTap: _toggleSave,
            child: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              size: 20.w,
              color: _isSaved ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildCommentHeader(CommentState state) {
    final count = state is CommentLoaded ? state.comments.length : 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: AppTheme.subtleBackground,
      child: Text('댓글 $count개',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyComments() => Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mode_comment_outlined,
                size: 40.w, color: AppTheme.secondaryTextColor),
            SizedBox(height: 12.h),
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

  Widget _buildCommentInput() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4.r,
                offset: Offset(0, -2.h))
          ],
        ),
        padding: EdgeInsets.only(
            left: 16.w,
            right: 8.w,
            top: 8.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8.h),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyToAuthorName != null)
                Container(
                  margin: EdgeInsets.only(bottom: 6.h),
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppTheme.subtleBackground,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(children: [
                    Icon(Icons.reply, size: 14.w, color: AppTheme.primaryColor),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        '${_replyToAuthorName!}에게 답글',
                        style: TextStyle(
                            fontSize: 12.sp, color: AppTheme.primaryColor),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: Icon(Icons.close,
                          size: 16.w, color: AppTheme.secondaryTextColor),
                    ),
                  ]),
                ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: _replyToAuthorName != null
                          ? '답글을 입력하세요...'
                          : '댓글을 입력하세요...',
                      hintStyle: TextStyle(
                          fontSize: 14.sp, color: AppTheme.hintColor),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide:
                              const BorderSide(color: AppTheme.dividerColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide:
                              const BorderSide(color: AppTheme.dividerColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide:
                              const BorderSide(color: AppTheme.primaryColor)),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 10.h),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                IconButton(
                    onPressed: _submitComment,
                    icon: Icon(Icons.send_rounded, size: 24.w),
                    color: AppTheme.primaryColor),
              ]),
            ],
          ),
        ),
      );

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
  const _MultiImageCarousel({required this.imageUrls});

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
            child: PageView.builder(
              controller: _pageController,
              itemCount: count,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, i) => CachedNetworkImage(
                imageUrl: widget.imageUrls[i],
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppTheme.subtleBackground),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.subtleBackground,
                  child: Icon(Icons.broken_image,
                      size: 48.w, color: AppTheme.hintColor),
                ),
              ),
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
                  color: _current == i
                      ? AppTheme.primaryColor
                      : Colors.grey[300],
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
