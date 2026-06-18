import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../news/domain/entities/news_article.dart';
import '../../../news/domain/usecases/get_published_news.dart';
import '../../../news/presentation/utils/news_format.dart';
import '../../../news/presentation/utils/news_link_launcher.dart';

/// 홈 "뉴스" 섹션 — 발행(published) 기사 최신 N건을 제목·발행일로 보여주고
/// 행 탭 시 원문 링크아웃, "더보기" 탭 시 /news 목록으로 이동.
/// 저작권: 제목·발행일·출처만(본문/썸네일 미표시). 0건이면 섹션 숨김.
class HomeNewsSection extends StatefulWidget {
  const HomeNewsSection({super.key});

  @override
  State<HomeNewsSection> createState() => _HomeNewsSectionState();
}

class _HomeNewsSectionState extends State<HomeNewsSection> {
  static const int _previewCount = 5;

  bool _loaded = false;
  List<NewsArticle> _articles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetPublishedNews>()(
      const GetPublishedNewsParams(offset: 0, limit: _previewCount),
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loaded = true), // 실패 → 빈 목록(섹션 숨김)
      (list) => setState(() {
        _loaded = true;
        _articles = list;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로드 전·0건·실패는 섹션 미노출(레이아웃 흔들림 방지).
    if (!_loaded || _articles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '뉴스',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/news'),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Text(
                      '더보기',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 16.w, color: AppTheme.secondaryTextColor),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...List.generate(_articles.length, (i) {
            final a = _articles[i];
            return _buildNewsRow(
              article: a,
              isLast: i == _articles.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNewsRow({
    required NewsArticle article,
    required bool isLast,
  }) {
    final date = formatNewsDate(article.publishedAt);
    return InkWell(
      onTap: () {
        AnalyticsService.instance
            .logNewsArticleOpen(sourceName: article.sourceName);
        openArticle(context, article.link);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                article.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.primaryTextColor.withValues(alpha: 0.85),
                ),
              ),
            ),
            SizedBox(width: 12.w),
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
    );
  }
}
