import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/news_article.dart';
import '../../domain/usecases/get_published_news.dart';

part 'news_event.dart';
part 'news_state.dart';

class NewsBloc extends Bloc<NewsEvent, NewsState> {
  final GetPublishedNews getPublishedNews;

  /// 한 페이지 크기. range 조회 결과 수가 이보다 작으면 마지막 페이지로 간주.
  static const int pageSize = 20;

  NewsBloc({required this.getPublishedNews}) : super(const NewsInitial()) {
    on<LoadNews>(_onLoadNews);
    on<RefreshNews>(_onRefreshNews);
    on<LoadMoreNews>(_onLoadMoreNews);
  }

  Future<void> _onLoadNews(LoadNews event, Emitter<NewsState> emit) async {
    emit(const NewsLoading());
    final result = await getPublishedNews(
      const GetPublishedNewsParams(offset: 0, limit: pageSize),
    );
    result.fold(
      (failure) => emit(NewsError(failure.message)),
      (articles) => emit(NewsLoaded(
        articles: articles,
        hasMore: articles.length >= pageSize,
      )),
    );
  }

  /// pull-to-refresh: 처음부터 다시 조회. 현재 목록은 유지(깜빡임 방지).
  Future<void> _onRefreshNews(RefreshNews event, Emitter<NewsState> emit) async {
    final result = await getPublishedNews(
      const GetPublishedNewsParams(offset: 0, limit: pageSize),
    );
    result.fold(
      (failure) {
        final s = state;
        // 이미 목록이 있으면 유지하고 에러만 표면화하지 않음(새로고침 실패는 조용히).
        if (s is! NewsLoaded) emit(NewsError(failure.message));
      },
      (articles) => emit(NewsLoaded(
        articles: articles,
        hasMore: articles.length >= pageSize,
      )),
    );
  }

  Future<void> _onLoadMoreNews(
      LoadMoreNews event, Emitter<NewsState> emit) async {
    final s = state;
    if (s is! NewsLoaded || !s.hasMore || s.isLoadingMore) return;

    emit(s.copyWith(isLoadingMore: true));
    final result = await getPublishedNews(
      GetPublishedNewsParams(offset: s.articles.length, limit: pageSize),
    );
    result.fold(
      (failure) => emit(s.copyWith(isLoadingMore: false)),
      (more) => emit(s.copyWith(
        articles: [...s.articles, ...more],
        hasMore: more.length >= pageSize,
        isLoadingMore: false,
      )),
    );
  }
}
