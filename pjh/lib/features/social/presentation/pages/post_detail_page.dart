import 'dart:developer' as dev;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    super.dispose();
  }

  Future<void> _loadPost() async {
    try {
      final res = await Supabase.instance.client
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .eq('id', widget.postId)
          .maybeSingle();
      if (mounted) setState(() { _post = res; _postLoading = false; });
    } catch (e) {
      dev.log('게시글 로드 실패: $e', name: 'PostDetailPage');
      if (mounted) setState(() => _postLoading = false);
    }
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
    final senderName = authState is AuthAuthenticated
        ? authState.user.displayName : '사용자';
    context.read<CommentBloc>().add(CreateCommentRequested(
      postId: widget.postId,
      content: content,
      postAuthorId: _post?['author_id'] as String?,
      senderName: senderName,
    ));
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CommentBloc(
        getComments: di.sl(), createComment: di.sl(),
        deleteComment: di.sl(), updateComment: di.sl(),
        currentUserId: Supabase.instance.client.auth.currentUser?.id ?? '',
      )..add(LoadComments(postId: widget.postId)),
      child: Scaffold(
        appBar: AppBar(
          title: Text('게시글', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Column(children: [
          Expanded(
            child: BlocConsumer<CommentBloc, CommentState>(
              listener: (context, state) {
                if (state is CommentError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor));
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
                      child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))),
                  if (state is CommentLoaded)
                    SliverList(delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        if (i == state.comments.length) {
                          return state.isLoadingMore
                            ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                            : const SizedBox.shrink();
                        }
                        final comment = state.comments[i];
                        final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
                        return CommentListItem(
                          comment: comment, currentUserId: myId,
                          onDelete: comment.authorId == myId
                            ? () => context.read<CommentBloc>().add(DeleteCommentRequested(commentId: comment.id))
                            : null,
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
    if (_postLoading) return Padding(padding: EdgeInsets.all(24.w), child: const Center(child: CircularProgressIndicator()));
    if (_post == null) return const SizedBox.shrink();

    final user = _post!['users'] as Map<String, dynamic>?;
    final authorName = user?['display_name'] as String? ?? '알 수 없음';
    final photoUrl = user?['photo_url'] as String?;
    final content = _post!['caption'] as String? ?? '';
    final imageUrl = _post!['image_url'] as String?;
    final createdAt = _post!['created_at'] as String? ?? '';
    final likesCount = _post!['likes_count'] as int? ?? 0;
    final commentsCount = _post!['comments_count'] as int? ?? 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppTheme.dividerColor))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20.r, backgroundColor: AppTheme.subtleBackground,
            backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
            child: photoUrl == null ? Icon(Icons.person, size: 20.w, color: AppTheme.hintColor) : null,
          ),
          SizedBox(width: 10.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(authorName, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            Text(_timeAgo(createdAt), style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
          ])),
        ]),
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: CachedNetworkImage(
              imageUrl: imageUrl, width: double.infinity, fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 200.h, color: AppTheme.subtleBackground),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        if (content.isNotEmpty) ...[SizedBox(height: 12.h), Text(content, style: TextStyle(fontSize: 14.sp, height: 1.6))],
        SizedBox(height: 12.h),
        Row(children: [
          Icon(Icons.favorite, size: 16.w, color: AppTheme.highlightColor),
          SizedBox(width: 4.w),
          Text('$likesCount', style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor)),
          SizedBox(width: 12.w),
          Icon(Icons.chat_bubble_outline, size: 16.w, color: AppTheme.secondaryTextColor),
          SizedBox(width: 4.w),
          Text('$commentsCount', style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor)),
        ]),
      ]),
    );
  }

  Widget _buildCommentHeader(CommentState state) {
    final count = state is CommentLoaded ? state.comments.length : 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      color: AppTheme.subtleBackground,
      child: Text('댓글 $count개', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyComments() => Padding(
    padding: EdgeInsets.symmetric(vertical: 40.h),
    child: Column(children: [
      Icon(Icons.chat_bubble_outline, size: 48.w, color: Colors.grey[300]),
      SizedBox(height: 12.h),
      Text('첫 번째 댓글을 작성해보세요!', style: TextStyle(fontSize: 14.sp, color: Colors.grey[500])),
    ]),
  );

  Widget _buildCommentInput() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4.r, offset: Offset(0, -2.h))],
    ),
    padding: EdgeInsets.only(left: 16.w, right: 8.w, top: 8.h, bottom: MediaQuery.of(context).viewInsets.bottom + 8.h),
    child: SafeArea(
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: '댓글을 입력하세요...', hintStyle: TextStyle(fontSize: 14.sp, color: AppTheme.hintColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide(color: AppTheme.dividerColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: BorderSide(color: AppTheme.dividerColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24.r), borderSide: const BorderSide(color: AppTheme.primaryColor)),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            ),
            maxLines: null, textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitComment(),
          ),
        ),
        IconButton(onPressed: _submitComment, icon: Icon(Icons.send_rounded, size: 24.w), color: AppTheme.primaryColor),
      ]),
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
    } catch (_) { return ''; }
  }
}
