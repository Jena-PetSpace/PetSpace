import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/feed_bloc.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_bottom_sheet.dart';

class FeedPage extends StatefulWidget {
  final String? userId;

  const FeedPage({
    super.key,
    this.userId,
  });

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<FeedBloc>().add(LoadFeedRequested(userId: widget.userId));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<FeedBloc>().add(LoadMorePostsRequested(userId: widget.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('피드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Navigate to search page
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to notifications page
            },
          ),
        ],
      ),
      body: BlocConsumer<FeedBloc, FeedState>(
        listener: (context, state) {
          if (state is FeedError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
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
            return const Center(child: CircularProgressIndicator());
          } else if (state is FeedLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<FeedBloc>().add(RefreshFeedRequested(userId: widget.userId));
              },
              child: _buildFeedList(state),
            );
          } else if (state is FeedError) {
            return _buildErrorState(state.message);
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostBottomSheet,
        child: const Icon(Icons.add),
      ),
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
            Navigator.pushNamed(
              context,
              '/comments',
              arguments: {'postId': post.id},
            );
          },
          onShare: () {
            // Handle share
            _sharePost(post);
          },
          onHashtagTap: (hashtag) {
            // Navigate to search page with hashtag
            Navigator.pushNamed(
              context,
              '/search',
              arguments: {'hashtag': hashtag},
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feed_outlined,
            size: 64.w,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            '아직 게시물이 없습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '첫 번째 게시물을 작성해보세요!',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: _showCreatePostBottomSheet,
            icon: const Icon(Icons.add),
            label: Text('게시물 작성', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
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
              color: Colors.grey[800],
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
              context.read<FeedBloc>().add(LoadFeedRequested(userId: widget.userId));
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