import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';

class MagazineGrid extends StatelessWidget {
  const MagazineGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '꿀팁 매거진',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/explore?query=매거진'),
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

          // 2열 그리드
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 0.85,
            children: [
              _buildMagazineItem(
                context: context,
                tag: '건강',
                tagColor: AppTheme.successColor,
                title: '반려동물 치아 관리\n필수 가이드',
              ),
              _buildMagazineItem(
                context: context,
                tag: '훈련',
                tagColor: AppTheme.accentColor,
                title: '기본 복종 훈련\n시작하기',
              ),
              _buildMagazineItem(
                context: context,
                tag: '먹거리',
                tagColor: AppTheme.highlightColor,
                title: '수제 간식 레시피\nTOP 5',
              ),
              _buildMagazineItem(
                context: context,
                tag: '생활',
                tagColor: AppTheme.subColor,
                title: '여름철 산책 시\n주의사항',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMagazineItem({
    required BuildContext context,
    required String tag,
    required Color tagColor,
    required String title,
  }) {
    return GestureDetector(
      onTap: () {
        context.push(
            '/explore?query=${Uri.encodeComponent(title.replaceAll('\n', ' '))}');
      },
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
            // 이미지 영역
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
                  // 태그 뱃지
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
                  // 제목
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
