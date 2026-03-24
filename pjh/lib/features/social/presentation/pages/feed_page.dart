import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_bottom_sheet.dart';
import '../widgets/edit_post_bottom_sheet.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/empty_state_widget.dart';

class FeedPage extends StatefulWidget {
  final String? userId;
  final bool followingOnly;

  const FeedPage({
    super.key,
    this.userId,
    this.followingOnly = false,
  });

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();

  String? get _effectiveUserId {
    if (widget.userId != null && widget.userId!.isNotEmpty)
      return widget.userId;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<FeedBloc>().add(LoadFeedRequested(
        userId: _effectiveUserId, followingOnly: widget.followingOnly));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<FeedBloc>().add(LoadMorePostsRequested(
          userId: widget.userId, followingOnly: widget.followingOnly));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedBloc, FeedState>(
      listener: (context, state) {
        if (state is FeedError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is FeedLoaded && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: '재시도',
                textColor: Colors.white,
                onPressed: () {
                  context
                      .read<FeedBloc>()
                      .add(LoadMorePostsRequested(userId: widget.userId));
                },
              ),
            ),
          );
        } else if (state is FeedPostCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시물이 성공적으로 작성되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is FeedLoading) {
          return const FeedShimmerLoading();
        } else if (state is FeedLoaded) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<FeedBloc>().add(RefreshFeedRequested(
                  userId: widget.userId, followingOnly: widget.followingOnly));
            },
            child: _buildFeedList(state),
          );
        } else if (state is FeedError) {
          return _buildErrorState(state.message);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildFeedList(FeedLoaded state) {
    if (state.posts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.posts.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final post = state.posts[index];
        return PostCard(
          post: post,
          currentUserId: widget.userId ?? '',
          onLike: () {
            if (post.isLikedByCurrentUser) {
              context.read<FeedBloc>().add(UnlikePostRequested(
                    postId: post.id,
                    userId: widget.userId ?? '',
                  ));
            } else {
              context.read<FeedBloc>().add(LikePostRequested(
                    postId: post.id,
                    userId: widget.userId ?? '',
                  ));
            }
          },
          onComment: () {
            // Navigate to comments page
            context.push('/post/${post.id}');
          },
          onShare: () {
            // Handle share
            _sharePost(post);
          },
          onEdit: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => EditPostBottomSheet(
                post: post,
                onSave: (updatedPost) {
                  context.read<FeedBloc>().add(
                        UpdatePostRequested(post: updatedPost),
                      );
                },
              ),
            );
          },
          onDelete: () {
            context.read<FeedBloc>().add(
                  DeletePostRequested(postId: post.id),
                );
          },
          onHashtagTap: (hashtag) {
            // Navigate to search page with hashtag
            context.push('/search?q=%23$hashtag');
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.feed_outlined,
      title: '아직 게시물이 없습니다',
      subtitle: '첫 번째 게시물을 작성해보세요!',
      actionLabel: '게시물 작성',
      onAction: _showCreatePostBottomSheet,
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: Colors.red,
          ),
          SizedBox(height: 16.h),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              context.read<FeedBloc>().add(LoadFeedRequested(
                  userId: widget.userId, followingOnly: widget.followingOnly));
            },
            child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  void _showCreatePostBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostBottomSheet(
        currentUserId: widget.userId ?? '',
        onPostCreated: (post) {
          context.read<FeedBloc>().add(CreatePostRequested(post: post));
        },
      ),
    );
  }

  void _sharePost(post) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공유 기능이 곧 추가됩니다!')),
    );
  }
}
