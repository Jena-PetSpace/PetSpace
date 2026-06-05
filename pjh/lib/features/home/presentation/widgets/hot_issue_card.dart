import 'dart:developer' as dev;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/repositories/social_repository.dart';

/// 핫이슈 — 지금 가장 인기 있는 게시글 1건을 썸네일+헤드라인+날짜 카드로.
class HotIssueCard extends StatefulWidget {
  const HotIssueCard({super.key});

  @override
  State<HotIssueCard> createState() => _HotIssueCardState();
}

class _HotIssueCardState extends State<HotIssueCard> {
  Post? _post;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = di.sl<SocialRepository>();
      final result = await repo.searchPostsByHashtag(hashtag: 'magazine', limit: 1);
      result.fold(
        (failure) {
          dev.log('핫이슈 로드 실패: ${failure.message}', name: 'HotIssueCard');
          if (mounted) setState(() => _loading = false);
        },
        (posts) {
          if (mounted) {
            setState(() {
              _post = posts.isNotEmpty ? posts.first : null;
              _loading = false;
            });
          }
        },
      );
    } catch (e) {
      dev.log('핫이슈 오류: $e', name: 'HotIssueCard');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '핫이슈',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 12.h),
          if (_loading)
            _buildSkeleton()
          else if (_post == null)
            _buildEmpty()
          else
            _buildCard(_post!),
        ],
      ),
    );
  }

  Widget _buildCard(Post post) {
    final imageUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 썸네일
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              width: 110.w,
              height: 90.h,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),
          ),
          SizedBox(width: 14.w),
          // 헤드라인 + 날짜
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.content ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  _formatDate(post.createdAt),
                  style: TextStyle(
                    fontSize: 11.sp,
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

  Widget _thumbPlaceholder() {
    return Container(
      color: AppTheme.backgroundColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 28.w,
        color: AppTheme.secondaryTextColor.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _buildEmpty() {
    return SizedBox(
      height: 90.h,
      child: Center(
        child: Text(
          '인기 게시글이 아직 없어요',
          style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Row(
      children: [
        Container(
          width: 110.w,
          height: 90.h,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(0.95),
              SizedBox(height: 8.h),
              _bar(0.7),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(double f) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: f,
        child: Container(
          height: 12.h,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
      );

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y.$m.$day.';
  }
}
