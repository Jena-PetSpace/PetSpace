import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';

class CommunityPreview extends StatefulWidget {
  final String? category;

  const CommunityPreview({super.key, this.category});

  @override
  State<CommunityPreview> createState() => _CommunityPreviewState();
}

class _CommunityPreviewState extends State<CommunityPreview> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void didUpdateWidget(CommunityPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      var query = supabase
          .from('posts')
          .select(
              'id, author_id, caption, hashtags, likes_count, comments_count, created_at, users!posts_author_id_fkey(display_name, photo_url)')
          .isFilter('deleted_at', null);

      if (widget.category != null) {
        query = query.contains('hashtags', [widget.category!]);
      }

      final response =
          await query.order('created_at', ascending: false).limit(3);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      dev.log('커뮤니티 프리뷰 로드 실패: $e', name: 'CommunityPreview');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getCategoryTitle() {
    switch (widget.category) {
      case 'health':
        return '🏥 건강 게시글';
      case 'training':
        return '🎯 훈련 게시글';
      default:
        return '💬 커뮤니티';
    }
  }

  String _getFeedTab() {
    switch (widget.category) {
      case 'health':
        return '/feed?tab=community&category=health';
      case 'training':
        return '/feed?tab=community&category=training';
      default:
        return '/feed?tab=community';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getCategoryTitle(),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              GestureDetector(
                onTap: () => context.go(_getFeedTab()),
                child: Text(
                  '더보기',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: const CircularProgressIndicator(),
            )
          else if (_posts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Text(
                '아직 게시글이 없습니다',
                style: TextStyle(
                    fontSize: 13.sp, color: AppTheme.secondaryTextColor),
              ),
            )
          else
            ..._posts.asMap().entries.map((entry) {
              final index = entry.key;
              final post = entry.value;
              final user = post['users'] as Map<String, dynamic>?;
              return Column(
                children: [
                  if (index > 0) SizedBox(height: 10.h),
                  _buildPreviewItem(
                    context: context,
                    postId: post['id'] as String,
                    author: user?['display_name'] as String? ?? '관리자',
                    content: post['caption'] as String? ?? '',
                    likes: post['likes_count'] as int? ?? 0,
                    comments: post['comments_count'] as int? ?? 0,
                    timeAgo: _timeAgo(post['created_at'] as String? ?? ''),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreviewItem({
    required BuildContext context,
    required String postId,
    required String author,
    required String content,
    required int likes,
    required int comments,
    required String timeAgo,
  }) {
    return GestureDetector(
      onTap: () => context.push('/post/$postId'),
      child: Container(
        decoration: AppTheme.cardDecoration,
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16.r,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person,
                      size: 16.w, color: AppTheme.primaryColor),
                ),
                SizedBox(width: 8.w),
                Text(
                  author,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              content,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.primaryTextColor,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.favorite_border,
                    size: 14.w, color: AppTheme.secondaryTextColor),
                SizedBox(width: 4.w),
                Text('$likes',
                    style: TextStyle(
                        fontSize: 10.sp, color: AppTheme.secondaryTextColor)),
                SizedBox(width: 12.w),
                Icon(Icons.chat_bubble_outline,
                    size: 14.w, color: AppTheme.secondaryTextColor),
                SizedBox(width: 4.w),
                Text('$comments',
                    style: TextStyle(
                        fontSize: 10.sp, color: AppTheme.secondaryTextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
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
