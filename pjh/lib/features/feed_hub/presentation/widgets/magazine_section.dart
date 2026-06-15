import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/repositories/social_repository.dart';

/// Q&A '전체' 탭 상단에 노출하는 매거진(전문가 칼럼) 가로 스크롤 섹션.
///
/// home 위젯을 건드리지 않고 social repository의 기존 조회
/// (searchPostsByHashtag('magazine'))를 재사용해 묻혀있던 매거진 글을 노출한다.
/// 글이 없으면 아무것도 그리지 않는다(SizedBox.shrink).
class MagazineSection extends StatefulWidget {
  const MagazineSection({super.key});

  @override
  State<MagazineSection> createState() => _MagazineSectionState();
}

class _MagazineSectionState extends State<MagazineSection> {
  List<Post> _posts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<SocialRepository>()
        .searchPostsByHashtag(hashtag: 'magazine', limit: 5);
    if (!mounted) return;
    result.fold(
      (failure) {
        dev.log('매거진 섹션 로드 실패: ${failure.message}', name: 'MagazineSection');
        setState(() => _loading = false);
      },
      (posts) => setState(() {
        _posts = posts;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _posts.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppTheme.surfaceColor,
      padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
      margin: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Text('📰', style: TextStyle(fontSize: 16.sp)),
                SizedBox(width: 6.w),
                Text(
                  '매거진',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/hashtag/magazine'),
                  child: Row(
                    children: [
                      Text(
                        '더보기',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16.w, color: AppTheme.secondaryTextColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          // 가로 카드 슬라이더
          SizedBox(
            height: 130.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _posts.length,
              separatorBuilder: (_, __) => SizedBox(width: 10.w),
              itemBuilder: (context, index) =>
                  _MagazineCard(post: _posts[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MagazineCard extends StatelessWidget {
  final Post post;
  const _MagazineCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final title = (post.content ?? '').split('\n').first.trim();
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        width: 220.w,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.accentColor],
          ),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '전문가 칼럼',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Text(
              title.isEmpty ? '매거진 글' : title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
