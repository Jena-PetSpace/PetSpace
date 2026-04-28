import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/repositories/social_repository.dart';

class UserPostsList extends StatefulWidget {
  final String userId;
  final bool isMyProfile;
  final String? petId;

  const UserPostsList({
    super.key,
    required this.userId,
    this.isMyProfile = false,
    this.petId,
  });

  @override
  State<UserPostsList> createState() => _UserPostsListState();
}

class _UserPostsListState extends State<UserPostsList> {
  static const _pageSize = 30;

  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _lastCreatedAt;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(UserPostsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId) {
      _loadPosts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadPosts() async {
    setState(() { _loading = true; _posts = []; _hasMore = true; _lastCreatedAt = null; });
    final result = await sl<SocialRepository>().getUserPostsFiltered(
      authorId: widget.userId,
      petId: widget.petId,
      limit: _pageSize,
    );
    if (!mounted) return;
    result.fold(
      (failure) {
        dev.log('UserPostsList load error: ${failure.message}',
            name: 'UserPostsList');
        setState(() => _loading = false);
      },
      (list) {
        setState(() {
          _posts = list;
          _loading = false;
          _hasMore = list.length == _pageSize;
          if (list.isNotEmpty) {
            _lastCreatedAt = list.last['created_at'] as String?;
          }
        });
      },
    );
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastCreatedAt == null) return;
    setState(() => _loadingMore = true);
    final result = await sl<SocialRepository>().getUserPostsFiltered(
      authorId: widget.userId,
      petId: widget.petId,
      beforeCreatedAt: _lastCreatedAt,
      limit: _pageSize,
    );
    if (!mounted) return;
    result.fold(
      (failure) {
        dev.log('UserPostsList loadMore error: ${failure.message}',
            name: 'UserPostsList');
        setState(() => _loadingMore = false);
      },
      (list) {
        setState(() {
          _posts = [..._posts, ...list];
          _loadingMore = false;
          _hasMore = list.length == _pageSize;
          if (list.isNotEmpty) {
            _lastCreatedAt = list.last['created_at'] as String?;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_posts.isEmpty) {
      return _buildEmpty();
    }
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.5.h,
        crossAxisSpacing: 1.5.w,
        childAspectRatio: 1.0,
      ),
      itemCount: _posts.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _posts.length) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final post = _posts[i];
        final postId = post['id'] as String;
        final postType = post['post_type'] as String? ?? '';
        final isEmotion = postType == 'emotion';
        final isMulti = postType == 'photo';

        final rawUrls = post['image_urls'];
        String? thumbUrl;
        int imageCount = 0;
        if (rawUrls != null && (rawUrls as List).isNotEmpty) {
          thumbUrl = rawUrls.first as String?;
          imageCount = rawUrls.length;
        } else {
          thumbUrl = post['image_url'] as String?;
          imageCount = thumbUrl != null ? 1 : 0;
        }

        final caption = post['caption'] as String? ?? '';

        return GestureDetector(
          onTap: () => context.push('/post/$postId'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              thumbUrl != null && thumbUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _colorBlock(postId, caption),
                    )
                  : _colorBlock(postId, caption),
              if (isEmotion)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 5.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.primaryColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '감정분석',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (isMulti && imageCount > 1)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(Icons.copy,
                      size: 14.w, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _colorBlock(String postId, String caption) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.accentColor,
      AppTheme.highlightColor,
      AppTheme.secondaryColor,
      AppTheme.successColor,
    ];
    final color = colors[postId.hashCode.abs() % colors.length];
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          caption.isNotEmpty ? caption[0] : '✍',
          style: TextStyle(fontSize: 24.sp, color: color),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_on_outlined,
                size: 48.w, color: AppTheme.lightTextColor),
            SizedBox(height: 16.h),
            Text(
              widget.isMyProfile
                  ? '아직 게시글이 없어요\n첫 이야기를 공유해보세요 📸'
                  : '게시글이 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.sp,
                  color: AppTheme.secondaryTextColor,
                  height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
