import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../../../shared/widgets/section_header.dart';

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
      final result = await repo.searchPostsByHashtag(hashtag: 'magazine', limit: 4);
      result.fold(
        (failure) {
          dev.log('매거진 로드 실패: \${failure.message}', name: 'MagazineGrid');
          if (mounted) setState(() => _loading = false);
        },
        (posts) {
          if (mounted) setState(() {
            _posts = posts;
            _loading = false;
          });
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
          SectionHeader(
            title: '📰 꿀팁 매거진',
            onMore: () => context.go('/feed?tab=community&category=magazine'),
          ),
          SizedBox(height: 12.h),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.85,
              children: _posts.map((post) {
                final hashtags = post.tags;
                final tag = _getTag(hashtags);
                return _buildMagazineItem(
                  context: context,
                  postId: post.id,
                  tag: tag['label']!,
                  tagColor: _getTagColor(tag['label']!),
                  title: post.content ?? '',
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Map<String, String> _getTag(List<String> hashtags) {
    for (final tag in hashtags) {
      if (tag == 'health') return {'label': '건강'};
      if (tag == 'training') return {'label': '훈련'};
      if (tag == 'food') return {'label': '먹거리'};
      if (tag == 'life') return {'label': '생활'};
    }
    return {'label': '매거진'};
  }

  Color _getTagColor(String label) {
    switch (label) {
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

  Widget _buildMagazineItem({
    required BuildContext context,
    required String postId,
    required String tag,
    required Color tagColor,
    required String title,
  }) {
    return GestureDetector(
      onTap: () => context.push('/post/$postId'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72.h,
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
              ),
              child: Center(
                child: Icon(Icons.article_outlined,
                    size: 32.w, color: tagColor.withValues(alpha: 0.4)),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w600,
                        color: tagColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryTextColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
