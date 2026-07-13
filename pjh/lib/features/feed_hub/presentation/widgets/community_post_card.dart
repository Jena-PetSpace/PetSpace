import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

class CommunityPostCard extends StatelessWidget {
  final String authorName;
  final String category;
  final String title;
  final String content;
  final int likes;
  final int comments;
  final String timeAgo;
  final bool isAdmin;

  const CommunityPostCard({
    super.key,
    required this.authorName,
    required this.category,
    required this.title,
    required this.content,
    required this.likes,
    required this.comments,
    required this.timeAgo,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: AppTheme.cardDecoration,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 + 시간
          Row(
            children: [
              // 아바타 폴백: 발바닥 아이콘 + 연블루 배경 (사람 아이콘 금지)
              CircleAvatar(
                radius: 16.r,
                backgroundColor: AppTheme.tilePastelBlue,
                child: Icon(Icons.pets,
                    size: 16.w, color: AppTheme.primaryColor),
              ),
              SizedBox(width: 8.w),
              Text(
                authorName,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const Spacer(),
              // 미분류(빈 라벨)면 칩 자체를 숨긴다 — 빈 파란 점 렌더 결함 방지.
              if (category.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (!isAdmin) ...[
                SizedBox(width: 8.w),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10.h),

          // 제목
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 4.h),

          // 본문
          Text(
            content,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.secondaryTextColor,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10.h),

          // 좋아요 / 댓글
          Row(
            children: [
              Icon(Icons.favorite_border,
                  size: 14.w, color: AppTheme.secondaryTextColor),
              SizedBox(width: 4.w),
              Text(
                '$likes',
                style: TextStyle(
                    fontSize: 10.sp, color: AppTheme.secondaryTextColor),
              ),
              SizedBox(width: 16.w),
              Icon(Icons.chat_bubble_outline,
                  size: 14.w, color: AppTheme.secondaryTextColor),
              SizedBox(width: 4.w),
              Text(
                '$comments',
                style: TextStyle(
                    fontSize: 10.sp, color: AppTheme.secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
