part of 'search_bloc.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class LoadDiscoveryRequested extends SearchEvent {
  const LoadDiscoveryRequested();
}

class SearchAllRequested extends SearchEvent {
  final String query;

  const SearchAllRequested({required this.query});

  @override
  List<Object?> get props => [query];
}

class SearchPostsRequested extends SearchEvent {
  final String query;
  final bool loadMore;

  const SearchPostsRequested({required this.query, this.loadMore = false});

  @override
  List<Object?> get props => [query, loadMore];
}

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

class SearchUsersRequested extends SearchEvent {
  final String query;
  final bool loadMore;

  const SearchUsersRequested({required this.query, this.loadMore = false});

  @override
  List<Object?> get props => [query, loadMore];
}

class GetPopularHashtagsRequested extends SearchEvent {
  final int limit;

  const GetPopularHashtagsRequested({this.limit = 20});

  @override
  List<Object?> get props => [limit];
}

class GetTrendingHashtagsRequested extends SearchEvent {
  final int limit;
  final int days;

  const GetTrendingHashtagsRequested({this.limit = 10, this.days = 7});

  @override
  List<Object?> get props => [limit, days];
}

class SearchPostChanged extends SearchEvent {
  final Post post;

  const SearchPostChanged(this.post);

  @override
  List<Object?> get props => [post];
}

class SearchPostRemoved extends SearchEvent {
  final String postId;

  const SearchPostRemoved(this.postId);

  @override
  List<Object?> get props => [postId];
}

class SearchFollowingChanged extends SearchEvent {
  final String userId;
  final bool isFollowing;

  const SearchFollowingChanged({
    required this.userId,
    required this.isFollowing,
  });

  @override
  List<Object?> get props => [userId, isFollowing];
}

class ClearSearchRequested extends SearchEvent {
  const ClearSearchRequested();
}
