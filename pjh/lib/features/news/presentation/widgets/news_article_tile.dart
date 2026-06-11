import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/news_article.dart';
import '../utils/news_format.dart';

/// 뉴스 목록 한 줄. 제목(네이비, 2줄 말줄임) + 하단 보조줄(출처 칩 · 발행일).
/// 썸네일 없음(저작권 — 자체 카테고리 아이콘으로 시각 보강). 빨강 미사용.
class NewsArticleTile extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const NewsArticleTile({
    super.key,
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = formatNewsDate(article.publishedAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 대체 — 네이비 톤 뉴스 아이콘(이미지 미복제)
            Container(
              width: 44.w,
              height: 44.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(Icons.article_outlined,
                  size: 22.sp, color: AppTheme.primaryColor),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      _sourceChip(article.sourceName),
                      if (dateText.isNotEmpty) ...[
                        SizedBox(width: 8.w),
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceChip(String source) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        source,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
