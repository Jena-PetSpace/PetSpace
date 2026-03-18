import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/presentation/bloc/feed_bloc.dart';

class MySavedPostsPage extends StatefulWidget {
  const MySavedPostsPage({super.key});

  @override
  State<MySavedPostsPage> createState() => _MySavedPostsPageState();
}

class _MySavedPostsPageState extends State<MySavedPostsPage> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<FeedBloc>().add(
            LoadSavedPostsRequested(userId: auth.user.uid),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '저장한 글',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<FeedBloc, FeedState>(
        buildWhen: (prev, curr) =>
            curr is FeedLoading ||
            curr is FeedSavedPostsLoaded ||
            curr is FeedError,
        builder: (context, state) {
          if (state is FeedLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is FeedError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48.w, color: Colors.red),
                  SizedBox(height: 12.h),
                  Text(state.message,
                      style: TextStyle(
                          fontSize: 14.sp, color: AppTheme.secondaryTextColor),
                      textAlign: TextAlign.center),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (state is FeedSavedPostsLoaded) {
            if (state.savedPosts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bookmark_border,
                        size: 64.w, color: Colors.grey[300]),
                    SizedBox(height: 16.h),
                    Text('저장한 글이 없습니다',
                        style: TextStyle(
                            fontSize: 16.sp, color: Colors.grey[500])),
                    SizedBox(height: 8.h),
                    Text('피드에서 마음에 드는 글을 저장해보세요',
                        style: TextStyle(
                            fontSize: 13.sp, color: Colors.grey[400])),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _load(),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                itemCount: state.savedPosts.length,
                itemBuilder: (context, index) {
                  final post = state.savedPosts[index];
                  return _SavedPostCard(
                    post: post,
                    onUnsave: () {
                      final auth = context.read<AuthBloc>().state;
                      if (auth is AuthAuthenticated) {
                        context.read<FeedBloc>().add(UnsavePostRequested(
                              postId: post.id,
                              userId: auth.user.uid,
                            ));
                        _load();
                      }
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── 저장한 글 카드 위젯 ─────────────────────────────────────────────────────
class _SavedPostCard extends StatelessWidget {
  final dynamic post;
  final VoidCallback onUnsave;

  const _SavedPostCard({required this.post, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (post.imageUrls as List?)?.isNotEmpty == true
        ? post.imageUrls.first as String
        : null;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 8.w, 8.h),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.15),
                  backgroundImage: post.authorProfileImage != null &&
                          (post.authorProfileImage as String).isNotEmpty
                      ? NetworkImage(post.authorProfileImage as String)
                      : null,
                  child: post.authorProfileImage == null ||
                          (post.authorProfileImage as String).isEmpty
                      ? Icon(Icons.person,
                          size: 18.w, color: AppTheme.primaryColor)
                      : null,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    post.authorName as String? ?? '사용자',
                    style:
                        TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                ),
                // 북마크 해제 버튼
                IconButton(
                  icon: Icon(Icons.bookmark,
                      color: AppTheme.primaryColor, size: 22.w),
                  onPressed: () => _confirmUnsave(context),
                  tooltip: '저장 취소',
                ),
              ],
            ),
          ),

          // 이미지
          if (imageUrl != null)
            ClipRRect(
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 200.h,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200.h,
                  color: Colors.grey[100],
                  child: Icon(Icons.broken_image,
                      size: 48.w, color: Colors.grey[300]),
                ),
              ),
            ),

          // 캡션
          if (post.content != null && (post.content as String).isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 4.h),
              child: Text(
                post.content as String,
                style: TextStyle(fontSize: 14.sp),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // 좋아요/댓글 수
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 12.h),
            child: Row(
              children: [
                Icon(Icons.favorite_border, size: 16.w, color: Colors.grey),
                SizedBox(width: 4.w),
                Text('${post.likesCount ?? 0}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
                SizedBox(width: 12.w),
                Icon(Icons.chat_bubble_outline, size: 16.w, color: Colors.grey),
                SizedBox(width: 4.w),
                Text('${post.commentsCount ?? 0}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnsave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장 취소'),
        content: const Text('이 게시글을 저장 목록에서 제거할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (ok == true) onUnsave();
  }
}
