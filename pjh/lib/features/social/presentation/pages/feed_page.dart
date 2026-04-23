import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_bottom_sheet.dart';
import '../widgets/edit_post_bottom_sheet.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/network_error_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../widgets/trending_hashtags_section.dart';

class FeedPage extends StatefulWidget {
  final String? userId;
  final bool followingOnly;
  final bool recommended;

  const FeedPage({
    super.key,
    this.userId,
    this.followingOnly = false,
    this.recommended = false,
  });

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();

  String? get _effectiveUserId {
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      return widget.userId;
    }
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.recommended) {
      final uid = _effectiveUserId;
      if (uid != null) {
        context.read<FeedBloc>().add(
            LoadRecommendedPostsRequested(userId: uid));
      }
    } else {
      context.read<FeedBloc>().add(LoadFeedRequested(
          userId: _effectiveUserId, followingOnly: widget.followingOnly));
    }
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
        } else if (state is FeedRecommendedLoaded) {
          return RefreshIndicator(
            onRefresh: () async {
              final uid = _effectiveUserId;
              if (uid != null) {
                context.read<FeedBloc>().add(
                    LoadRecommendedPostsRequested(userId: uid));
              }
            },
            child: _buildRecommendedList(state),
          );
        } else if (state is FeedLoaded) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<FeedBloc>().add(RefreshFeedRequested(
                  userId: widget.userId, followingOnly: widget.followingOnly));
            },
            child: _buildFeedList(state),
          );
        } else if (state is FeedError) {
          if (state.isNetworkError) {
            return _buildNetworkErrorState();
          }
          return _buildErrorState(state.message);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRecommendedList(FeedRecommendedLoaded state) {
    if (state.posts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0) + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const TrendingHashtagsSection();
        final postIndex = index - 1;
        if (postIndex >= state.posts.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final post = state.posts[postIndex];
        return _buildPostCard(post);
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
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(post) {
    final uid = _effectiveUserId ?? '';
    return PostCard(
      post: post,
      currentUserId: uid,
      onLike: () {
        if (uid.isEmpty) return;
        if (post.isLikedByCurrentUser) {
          context.read<FeedBloc>().add(UnlikePostRequested(
                postId: post.id,
                userId: uid,
              ));
        } else {
          context.read<FeedBloc>().add(LikePostRequested(
                postId: post.id,
                userId: uid,
              ));
        }
      },
      onComment: () => context.push('/post/${post.id}'),
      onShare: () => _sharePost(post),
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
        context.read<FeedBloc>().add(DeletePostRequested(postId: post.id));
      },
      onHashtagTap: (hashtag) => context.push('/hashtag/$hashtag'),
    );
  }

  Widget _buildEmptyState() {
    final isFollowing = widget.followingOnly;
    return EmptyStateWidget(
      icon: Icons.feed_outlined,
      emoji: isFollowing ? '🐾' : '🐾',
      badgeEmoji: '✨',
      title: isFollowing ? '팔로잉 피드가 비어있어요' : '아직 게시물이 없어요',
      subtitle: isFollowing
          ? '친구를 팔로우하고\n반려동물 일상을 함께해보세요!'
          : '반려동물의 일상을 공유하고\n친구들과 소통해보세요!',
      secondaryLabel: isFollowing ? '탐색하기' : null,
      onSecondary: isFollowing ? () => context.go('/explore') : null,
      actionLabel: '첫 게시물 작성',
      onAction: _showCreatePostBottomSheet,
    );
  }

  Widget _buildNetworkErrorState() {
    return NetworkErrorScreen(
      onRetry: () => context.read<FeedBloc>().add(
            LoadFeedRequested(
                userId: widget.userId, followingOnly: widget.followingOnly),
          ),
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
        currentUserId: _effectiveUserId ?? '',
        onPostCreated: (post) {
          context.read<FeedBloc>().add(CreatePostRequested(post: post));
        },
      ),
    );
  }

  void _sharePost(post) {
    final caption = post.caption ?? '';
    final preview =
        caption.length > 100 ? '${caption.substring(0, 100)}...' : caption;
    Share.share('$preview\n\nPetSpace에서 확인하세요!');
  }
}
