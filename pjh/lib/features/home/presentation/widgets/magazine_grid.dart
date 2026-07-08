import 'dart:developer' as dev;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/repositories/social_repository.dart';

class MagazineGrid extends StatefulWidget {
  const MagazineGrid({super.key});

  @override
  State<MagazineGrid> createState() => _MagazineGridState();
}

class _MagazineGridState extends State<MagazineGrid> {
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final repo = di.sl<SocialRepository>();
      final result = await repo.searchPostsByHashtag(hashtag: 'magazine', limit: 3);
      result.fold(
        (failure) {
          dev.log('매거진 로드 실패: \${failure.message}', name: 'MagazineGrid');
          if (mounted) setState(() => _loading = false);
        },
        (posts) {
          if (mounted) {
            setState(() {
              _posts = posts;
              _loading = false;
            });
          }
        },
      );
    } catch (e) {
      dev.log('매거진 오류: \$e', name: 'MagazineGrid');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          // 섹션 헤더는 홈 페이지에서 제공 (매거진 + 더보기)
          if (_loading)
            SizedBox(
              height: 120.h,
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_posts.isEmpty)
            SizedBox(
              height: 120.h,
              child: Center(
                child: Text(
                  '매거진 게시글이 없습니다',
                  style: TextStyle(
                      fontSize: 13.sp, color: AppTheme.secondaryTextColor),
                ),
              ),
            )
          else
            Column(
              children: List.generate(_posts.length, (i) {
                final post = _posts[i];
                final tag = _getTag(post.tags);
                return Padding(
                  padding: EdgeInsets.only(bottom: i == _posts.length - 1 ? 0 : 16.h),
                  child: _buildMagazineItem(
                    context: context,
                    postId: post.id,
                    tag: tag['label']!,
                    tagColor: _getTagColor(tag['label']!),
                    title: post.content ?? '',
                    date: _formatDate(post.createdAt),
                    imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls.first : null,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Map<String, String> _getTag(List<String> hashtags) {
    for (final tag in hashtags) {
      if (tag == 'quiz') return {'label': 'O/X 퀴즈'};
      if (tag == 'careguide') return {'label': '케어가이드'};
      if (tag == 'education') return {'label': '교육'};
      if (tag == 'policy') return {'label': '정책'};
      if (tag == 'event') return {'label': '이벤트'};
      // ── 구 분류 체계(2026-07 개편 이전 글) 호환 ──
      if (tag == 'health') return {'label': '건강'};
      if (tag == 'training') return {'label': '훈련'};
      if (tag == 'food') return {'label': '먹거리'};
      if (tag == 'life') return {'label': '생활'};
    }
    return {'label': '매거진'};
  }

  Color _getTagColor(String label) {
    switch (label) {
      case 'O/X 퀴즈':
        return AppTheme.accentColor;
      case '케어가이드':
        return AppTheme.successColor;
      case '교육':
        return AppTheme.subColor;
      case '정책':
        return AppTheme.primaryColor;
      case '이벤트':
        return AppTheme.highlightColor;
      // ── 구 분류 체계 호환 ──
      case '건강':
        return AppTheme.successColor;
      case '훈련':
        return AppTheme.accentColor;
      case '먹거리':
        return AppTheme.highlightColor;
      case '생활':
        return AppTheme.subColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _buildImagePlaceholder(Color tagColor) {
    return Container(
      color: tagColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(Icons.article_outlined, size: 28.w, color: tagColor.withValues(alpha: 0.4)),
      ),
    );
  }

  // 시안 매거진 행: [썸네일] + [태그·제목 / 날짜] 가로 레이아웃
  Widget _buildMagazineItem({
    required BuildContext context,
    required String postId,
    required String tag,
    required Color tagColor,
    required String title,
    required String date,
    String? imageUrl,
  }) {
    return GestureDetector(
      onTap: () => context.push('/post/$postId'),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              width: 96.w,
              height: 80.h,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildImagePlaceholder(tagColor),
                    )
                  : _buildImagePlaceholder(tagColor),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: tagColor,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8.h),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y.$m.$day.';
  }
}
