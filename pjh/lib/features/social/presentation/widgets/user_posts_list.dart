import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/injection_container.dart';
import '../../../../core/utils/public_ai_text.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/repositories/social_repository.dart';

class UserPostsList extends StatefulWidget {
  final String userId;
  final bool isMyProfile;
  final String? petId;
  final SocialRepository? repository;

  const UserPostsList({
    super.key,
    required this.userId,
    this.isMyProfile = false,
    this.petId,
    this.repository,
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
  bool _firstLoadError = false;
  bool _loadMoreError = false;
  String? _lastCreatedAt;
  int _requestToken = 0;
  late final SocialRepository _repository;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<SocialRepository>();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(UserPostsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId || oldWidget.userId != widget.userId) {
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
    final requestToken = ++_requestToken;
    final userId = widget.userId;
    final petId = widget.petId;
    setState(() {
      _loading = true;
      _posts = [];
      _hasMore = true;
      _firstLoadError = false;
      _loadMoreError = false;
      _lastCreatedAt = null;
    });
    final result = await _repository.getUserPostsFiltered(
      authorId: userId,
      petId: petId,
      limit: _pageSize,
    );
    if (!mounted || requestToken != _requestToken) return;
    result.fold(
      (failure) {
        dev.log(
          'UserPostsList load error: ${failure.message}',
          name: 'UserPostsList',
        );
        setState(() {
          _loading = false;
          _firstLoadError = true;
        });
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
    final requestToken = _requestToken;
    final userId = widget.userId;
    final petId = widget.petId;
    setState(() {
      _loadingMore = true;
      _loadMoreError = false;
    });
    final result = await _repository.getUserPostsFiltered(
      authorId: userId,
      petId: petId,
      beforeCreatedAt: _lastCreatedAt,
      limit: _pageSize,
    );
    if (!mounted || requestToken != _requestToken) return;
    result.fold(
      (failure) {
        dev.log(
          'UserPostsList loadMore error: ${failure.message}',
          name: 'UserPostsList',
        );
        setState(() {
          _loadingMore = false;
          _loadMoreError = true;
        });
      },
      (list) {
        setState(() {
          final knownIds = _posts.map((post) => post['id']).toSet();
          _posts = [
            ..._posts,
            ...list.where((post) => knownIds.add(post['id'])),
          ];
          _loadingMore = false;
          _loadMoreError = false;
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
    if (_firstLoadError) {
      return _buildError();
    }
    if (_posts.isEmpty) {
      return _buildEmpty();
    }
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            key: const Key('user_posts_grid'),
            controller: _scrollController,
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 1.5.h,
              crossAxisSpacing: 1.5.w,
              childAspectRatio: 1.0,
            ),
            itemCount: _posts.length,
            itemBuilder: (context, i) {
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

              final caption = publicAiText(post['caption'] as String? ?? '');

              return Semantics(
                button: true,
                label: '게시물 상세 보기',
                child: InkWell(
                  onTap: () => context.push('/post/$postId'),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      thumbUrl != null && thumbUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: thumbUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _neutralPreview(caption),
                            )
                          : _neutralPreview(caption),
                      if (isEmotion)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              '감정분석',
                              style: TextStyle(
                                fontSize: 12.sp,
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
                          child: Icon(
                            Icons.copy,
                            size: 14.w,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_loadingMore)
          Padding(
            padding: EdgeInsets.all(12.h),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        if (_loadMoreError)
          TextButton.icon(
            key: const Key('user_posts_load_more_retry'),
            onPressed: _loadMore,
            icon: const Icon(Icons.refresh),
            label: const Text('게시물 더 불러오기'),
          ),
      ],
    );
  }

  Widget _neutralPreview(String caption) {
    final text = caption.trim();
    return Container(
      color: AppTheme.subtleBackground,
      padding: EdgeInsets.all(12.w),
      child: Center(
        child: text.isEmpty
            ? Icon(
                Icons.notes_rounded,
                size: 26.w,
                color: AppTheme.lightTextColor,
              )
            : Text(
                text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.4,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44.w,
              color: AppTheme.lightTextColor,
            ),
            SizedBox(height: 14.h),
            Text(
              '게시물을 불러오지 못했어요',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '연결 상태를 확인하고 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              key: const Key('user_posts_retry'),
              onPressed: _loadPosts,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
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
            Icon(
              Icons.grid_on_outlined,
              size: 48.w,
              color: AppTheme.lightTextColor,
            ),
            SizedBox(height: 16.h),
            Text(
              widget.isMyProfile ? '아직 게시글이 없어요\n첫 이야기를 공유해보세요' : '게시글이 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
