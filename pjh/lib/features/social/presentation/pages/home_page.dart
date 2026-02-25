import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../chat/presentation/bloc/chat_badge/chat_badge_bloc.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/post_card.dart';
import '../widgets/edit_post_bottom_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FeedBloc>().add(const LoadFeedRequested());
        _loadChatBadge();
        // 30초마다 뱃지 갱신
        _badgeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) _loadChatBadge();
        });
      }
    });
  }

  void _loadChatBadge() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<ChatBadgeBloc>().add(
        ChatBadgeLoadRequested(userId: authState.user.id),
      );
    }
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<FeedBloc>().add(const LoadMorePostsRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          height: 42.h,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          BlocBuilder<ChatBadgeBloc, ChatBadgeState>(
            builder: (context, badgeState) {
              final iconColor = IconTheme.of(context).color ?? Colors.black87;
              final chatIcon = SizedBox(
                width: 24.w,
                height: 24.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(24.w, 24.w),
                      painter: _ChatBubblePainter(color: iconColor),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 3.h),
                      child: Icon(Icons.pets, size: 11.w, color: iconColor),
                    ),
                  ],
                ),
              );
              return IconButton(
                icon: badgeState.count > 0
                    ? Badge(
                        label: Text(
                          badgeState.count > 99 ? '99+' : '${badgeState.count}',
                          style: TextStyle(fontSize: 10.sp),
                        ),
                        child: chatIcon,
                      )
                    : chatIcon,
                onPressed: () => context.push('/chat'),
              );
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
          }
        },
        builder: (context, state) {
          // 초기 상태나 로딩 중일 때 로딩 인디케이터 표시
          if (state is FeedInitial || (state is FeedLoading && state is! FeedLoaded)) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is FeedLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<FeedBloc>().add(const RefreshFeedRequested());
                await Future.delayed(const Duration(seconds: 1));
              },
              child: _buildFeedList(state),
            );
          } else if (state is FeedError) {
            return _buildEmptyState(state.message);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildFeedList(FeedLoaded state) {
    if (state.posts.isEmpty) {
      return _buildEmptyState(null);
    }

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final currentUserId = authState is AuthAuthenticated
            ? authState.user.id
            : '';

        return ListView.builder(
          controller: _scrollController,
          itemCount: state.posts.length + (!state.hasReachedMax ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= state.posts.length) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: const CircularProgressIndicator(),
                ),
              );
            }

            final post = state.posts[index];
            return PostCard(
              post: post,
              currentUserId: currentUserId,
              onLike: () {
                if (post.isLikedByCurrentUser) {
                  context.read<FeedBloc>().add(
                    UnlikePostRequested(
                      postId: post.id,
                      userId: currentUserId,
                    ),
                  );
                } else {
                  context.read<FeedBloc>().add(
                    LikePostRequested(
                      postId: post.id,
                      userId: currentUserId,
                    ),
                  );
                }
              },
              onComment: () {
                context.push('/post/${post.id}');
              },
              onShare: () {
                _sharePost(post);
              },
              onDelete: post.authorId == currentUserId
                  ? () {
                      context.read<FeedBloc>().add(
                        DeletePostRequested(postId: post.id),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('게시물이 삭제되었습니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
              onEdit: post.authorId == currentUserId
                  ? () => _showEditPostBottomSheet(post)
                  : null,
              onHashtagTap: (hashtag) {
                context.go('/explore?hashtag=$hashtag');
              },
            );
          },
        );
      },
    );
  }

  Future<void> _sharePost(dynamic post) async {
    try {
      final shareText = '${post.authorName}님의 게시물\n'
          '${post.content ?? ""}\n\n'
          '펫페이스에서 확인하기';

      await Share.share(
        shareText,
        subject: '펫페이스 게시물 공유',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('공유 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditPostBottomSheet(dynamic post) {
    final feedBloc = context.read<FeedBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => EditPostBottomSheet(
        post: post,
        onSave: (updatedPost) {
          feedBloc.add(UpdatePostRequested(post: updatedPost));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시물이 수정되었습니다'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String? errorMessage) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              errorMessage != null ? Icons.error_outline : Icons.pets,
              size: 80.w,
              color: Colors.grey,
            ),
            SizedBox(height: 16.h),
            Text(
              errorMessage != null ? '오류 발생' : '아직 게시물이 없습니다',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              errorMessage ?? '첫 번째 게시물을 작성해보세요!',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16.sp,
              ),
              textAlign: TextAlign.center,
            ),
            if (errorMessage == null) ...[
              SizedBox(height: 24.h),
              ElevatedButton.icon(
                onPressed: () => context.go('/create-post'),
                icon: const Icon(Icons.add),
                label: Text('게시물 작성하기', style: TextStyle(fontSize: 14.sp)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatBubblePainter extends CustomPainter {
  final Color color;

  _ChatBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final w = size.width;
    final h = size.height;

    // 둥근 말풍선 본체 (원형에 가까운 둥근 사각형)
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, 0, w * 0.9, h * 0.78),
      Radius.circular(w * 0.35),
    );
    canvas.drawRRect(bubbleRect, paint);

    // 말꼬리 (왼쪽 아래)
    final tailPath = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..quadraticBezierTo(w * 0.15, h * 0.95, w * 0.08, h * 0.98)
      ..quadraticBezierTo(w * 0.25, h * 0.88, w * 0.35, h * 0.78);

    canvas.drawPath(tailPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
