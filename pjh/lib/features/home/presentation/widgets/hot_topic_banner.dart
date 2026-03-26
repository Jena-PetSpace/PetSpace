import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';

class HotTopicBanner extends StatelessWidget {
  const HotTopicBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/feed?tab=community'),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.secondaryColor, AppTheme.accentColor],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\uD83D\uDD25 이번 주 인기 토픽',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '우리 아이 산책 꿀팁 대방출!',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Text(
                  '참여자 128명 · 게시글 56개',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    size: 12.w, color: Colors.white.withValues(alpha: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
