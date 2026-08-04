import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../bloc/news_bloc.dart';
import '../utils/news_link_launcher.dart';
import '../widgets/news_article_tile.dart';

/// 펫 뉴스 목록 화면(/news). 발행(published) 기사 최신순.
/// pull-to-refresh + 무한 스크롤 페이지네이션 + 빈/에러 상태.
/// 기사 탭 → 원문 링크아웃(본문 미표시).
class NewsListPage extends StatelessWidget {
  const NewsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NewsBloc>()..add(const LoadNews()),
      child: const _NewsListView(),
    );
  }
}

class _NewsListView extends StatefulWidget {
  const _NewsListView();

  @override
  State<_NewsListView> createState() => _NewsListViewState();
}

class _NewsListViewState extends State<_NewsListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 목록 진입 1회 집계(익명).
    AnalyticsService.instance.logNewsListView();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 바닥 근처(300px 이내) 도달 시 다음 페이지 로드.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      context.read<NewsBloc>().add(const LoadMoreNews());
    }
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<NewsBloc>()..add(const RefreshNews());
    // 다음 Loaded/Error 가 방출될 때까지 대기(인디케이터 유지).
    await bloc.stream.firstWhere((s) => s is NewsLoaded || s is NewsError);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('펫 뉴스'),
        centerTitle: true,
      ),
      body: BlocBuilder<NewsBloc, NewsState>(
        builder: (context, state) {
          if (state is NewsLoading || state is NewsInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NewsError) {
            return _ErrorView(
              message: publicErrorMessage(
                state.message,
                fallback: '소식을 불러오지 못했어요. 잠시 후 다시 시도해주세요.',
              ),
              onRetry: () => context.read<NewsBloc>().add(const LoadNews()),
            );
          }

          if (state is NewsLoaded) {
            if (state.articles.isEmpty) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(
                  // 빈 상태에서도 당겨서 새로고침 가능하도록 스크롤 가능 영역 확보
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 120.h),
                    const EmptyStateWidget(
                      icon: Icons.article_outlined,
                      title: '아직 소식이 없어요',
                      subtitle: '새로운 펫 뉴스가 올라오면\n여기에서 모아 보여드릴게요.',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppTheme.primaryColor,
              child: ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 8.h),
                itemCount: state.articles.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16.w,
                  endIndent: 16.w,
                  color: AppTheme.dividerColor,
                ),
                itemBuilder: (context, index) {
                  // 마지막 로딩 인디케이터(페이지네이션)
                  if (index >= state.articles.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    );
                  }

                  final article = state.articles[index];
                  return NewsArticleTile(
                    article: article,
                    onTap: () {
                      AnalyticsService.instance
                          .logNewsArticleOpen(sourceName: article.sourceName);
                      openArticle(context, article.link);
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                size: 48.sp, color: AppTheme.secondaryTextColor),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16.h),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
