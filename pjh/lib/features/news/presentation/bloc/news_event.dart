part of 'news_bloc.dart';

abstract class NewsEvent extends Equatable {
  const NewsEvent();

  @override
  List<Object?> get props => [];
}

/// 최초 진입 시 첫 페이지 로드.
class LoadNews extends NewsEvent {
  const LoadNews();
}

/// pull-to-refresh: 첫 페이지부터 다시 조회.
class RefreshNews extends NewsEvent {
  const RefreshNews();
}

/// 무한 스크롤: 다음 페이지 추가 로드.
class LoadMoreNews extends NewsEvent {
  const LoadMoreNews();
}
