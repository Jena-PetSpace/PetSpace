import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/usecases/get_published_news.dart';
import '../utils/news_format.dart';

/// 홈 "오늘의 펫 소식" 카드. 발행 기사 최신 1~3건 미리보기 → 탭하면 /news.
/// 운세·퀴즈 카드와 동일 톤·radius(16)·여백. 본문/썸네일 미표시(저작권).
/// 발행분이 0건이거나 로드 실패면 카드를 숨겨 홈을 깔끔히 유지한다.
class HomeNewsCard extends StatefulWidget {
  const HomeNewsCard({super.key});

  @override
  State<HomeNewsCard> createState() => _HomeNewsCardState();
}

class _HomeNewsCardState extends State<HomeNewsCard> {
  static const int _previewCount = 3;

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
      (_) => setState(() => _loaded = true), // 실패 → 빈 목록 유지(카드 숨김)
      (list) => setState(() {
        _loaded = true;
        _articles = list;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로드 전·0건·실패는 카드 미노출(레이아웃 흔들림 방지 — 자리 차지 안 함).
    if (!_loaded || _articles.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => context.push('/news'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 이모지 + 타이틀 + 더보기 chevron
              Row(
                children: [
                  Text('📰', style: TextStyle(fontSize: 22.sp)),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      '오늘의 펫 소식',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  Text(
                    '더보기',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 18.w, color: AppTheme.secondaryTextColor),
                ],
              ),
              SizedBox(height: 10.h),
              // 미리보기 항목들(제목 1줄 + 출처·발행일)
              for (var i = 0; i < _articles.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: const Divider(
                        height: 1, thickness: 1, color: AppTheme.dividerColor),
                  ),
                _previewItem(_articles[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewItem(NewsArticle a) {
    final date = formatNewsDate(a.publishedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryTextColor,
            height: 1.3,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          date.isEmpty ? a.sourceName : '${a.sourceName} · $date',
          style: TextStyle(
            fontSize: 11.sp,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }
}
