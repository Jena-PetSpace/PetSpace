part of 'search_bloc.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// 통합 검색 요청
class SearchAllRequested extends SearchEvent {
  final String query;

  const SearchAllRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

/// 게시물 검색 요청
class SearchPostsRequested extends SearchEvent {
  final String query;
  final bool loadMore;

  const SearchPostsRequested({
    required this.query,
    this.loadMore = false,
  });

  @override
  List<Object?> get props => [query, loadMore];
}

/// 해시태그로 게시물 검색 요청
class SearchPostsByHashtagRequested extends SearchEvent {
  final String hashtag;
  final bool loadMore;

  const SearchPostsByHashtagRequested({
    required this.hashtag,
    this.loadMore = false,
  });

  @override
  List<Object?> get props => [hashtag, loadMore];
}

/// 사용자 검색 요청
class SearchUsersRequested extends SearchEvent {
  final String query;
  final bool loadMore;

  const SearchUsersRequested({
    required this.query,
    this.loadMore = false,
  });

  @override
  List<Object?> get props => [query, loadMore];
}

/// 인기 해시태그 조회 요청
class GetPopularHashtagsRequested extends SearchEvent {
  final int limit;

  const GetPopularHashtagsRequested({this.limit = 20});

  @override
  List<Object?> get props => [limit];
}

/// 트렌딩 해시태그 조회 요청
class GetTrendingHashtagsRequested extends SearchEvent {
  final int limit;
  final int days;

  const GetTrendingHashtagsRequested({
    this.limit = 10,
    this.days = 7,
  });

  @override
  List<Object?> get props => [limit, days];
}

/// 검색 결과 초기화
class ClearSearchRequested extends SearchEvent {
  const ClearSearchRequested();
}
