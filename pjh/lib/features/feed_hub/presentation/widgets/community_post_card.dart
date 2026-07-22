import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';

class CommunityPostCard extends StatelessWidget {
  final String authorName;
  final String? authorPhotoUrl;
  final String category;
  final String title;
  final String content;
  final int likes;
  final int comments;
  final String timeAgo;
  final bool isAdmin;
  final VoidCallback? onTap;

  const CommunityPostCard({
    super.key,
    required this.authorName,
    this.authorPhotoUrl,
    required this.category,
    required this.title,
    required this.content,
    required this.likes,
    required this.comments,
    required this.timeAgo,
    this.isAdmin = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                    backgroundImage: authorPhotoUrl?.trim().isNotEmpty == true
                        ? CachedNetworkImageProvider(authorPhotoUrl!)
                        : null,
                    child: authorPhotoUrl?.trim().isNotEmpty == true
                        ? null
                        : Icon(
                            Icons.pets,
                            size: 16.w,
                            color: AppTheme.primaryColor,
                          ),
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
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      timeAgo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTheme.fontMicro.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // 미분류(빈 라벨)면 칩 자체를 숨긴다 — 빈 파란 점 렌더 결함 방지.
                  if (category.isNotEmpty)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
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
                ],
              ),
              SizedBox(height: 10.h),

              // 제목
              if (title.isNotEmpty) ...[
                Text(
                  title,
                  key: const Key('community_post_title'),
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 5.h),
              ],

              // 본문
              if (content.isNotEmpty)
                Text(
                  content,
                  key: const Key('community_post_body'),
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                )
              else if (title.isEmpty)
                Text(
                  '내용이 없는 글이에요.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              SizedBox(height: 10.h),

              // 좋아요 / 댓글
              Row(
                children: [
                  Icon(Icons.favorite_border,
                      size: 14.w, color: AppTheme.secondaryTextColor),
                  SizedBox(width: 4.w),
                  Text(
                    '좋아요 $likes',
                    style: TextStyle(
                        fontSize: 10.sp, color: AppTheme.secondaryTextColor),
                  ),
                  SizedBox(width: 16.w),
                  Icon(Icons.chat_bubble_outline,
                      size: 14.w, color: AppTheme.secondaryTextColor),
                  SizedBox(width: 4.w),
                  Text(
                    '댓글 $comments',
                    style: TextStyle(
                        fontSize: 10.sp, color: AppTheme.secondaryTextColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
