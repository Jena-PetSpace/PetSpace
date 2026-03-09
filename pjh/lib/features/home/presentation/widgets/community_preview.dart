import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';

class CommunityPreview extends StatelessWidget {
  const CommunityPreview({super.key});

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
                '\uD83D\uDCAC 커뮤니티',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/feed?tab=community'),
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

          // 카드 리스트
          _buildPreviewItem(
            context: context,
            author: '멍멍이집사',
            content: '강아지 눈물자국 관리 이렇게 했더니 효과 봤어요! 일주일만에 확 줄었습니다.',
            likes: 24,
            comments: 8,
            timeAgo: '30분 전',
          ),
          SizedBox(height: 10.h),
          _buildPreviewItem(
            context: context,
            author: '냥이사랑',
            content: '고양이 캣타워 추천 부탁드려요. 대형묘인데 튼튼한 거 찾고 있습니다.',
            likes: 15,
            comments: 12,
            timeAgo: '1시간 전',
          ),
          SizedBox(height: 10.h),
          _buildPreviewItem(
            context: context,
            author: '초보집사',
            content: '생후 3개월 강아지 예방접종 스케줄 어떻게 잡아야 하나요?',
            likes: 31,
            comments: 6,
            timeAgo: '2시간 전',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem({
    required BuildContext context,
    required String author,
    required String content,
    required int likes,
    required int comments,
    required String timeAgo,
  }) {
    return GestureDetector(
      onTap: () => context.go('/feed?tab=community'),
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
                  child: Icon(Icons.person, size: 16.w, color: AppTheme.primaryColor),
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
                Icon(Icons.favorite_border, size: 14.w, color: AppTheme.secondaryTextColor),
                SizedBox(width: 4.w),
                Text('$likes', style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor)),
                SizedBox(width: 12.w),
                Icon(Icons.chat_bubble_outline, size: 14.w, color: AppTheme.secondaryTextColor),
                SizedBox(width: 4.w),
                Text('$comments', style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
