part of 'search_bloc.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

/// 초기 상태
class SearchInitial extends SearchState {
  const SearchInitial();
}

/// 검색 중
class SearchLoading extends SearchState {
  const SearchLoading();
}

/// 검색 성공
class SearchSuccess extends SearchState {
  final List<Post> posts;
  final List<SocialUser> users;
  final List<String> hashtags;
  final String query;
  final bool hasMorePosts;
  final bool hasMoreUsers;

  const SearchSuccess({
    required this.posts,
    required this.users,
    required this.hashtags,
    required this.query,
    this.hasMorePosts = false,
    this.hasMoreUsers = false,
  });

  @override
  List<Object?> get props => [
        posts,
        users,
        hashtags,
        query,
        hasMorePosts,
        hasMoreUsers,
      ];

  SearchSuccess copyWith({
    List<Post>? posts,
    List<SocialUser>? users,
    List<String>? hashtags,
    String? query,
    bool? hasMorePosts,
    bool? hasMoreUsers,
  }) {
    return SearchSuccess(
      posts: posts ?? this.posts,
      users: users ?? this.users,
      hashtags: hashtags ?? this.hashtags,
      query: query ?? this.query,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      hasMoreUsers: hasMoreUsers ?? this.hasMoreUsers,
    );
  }
}

/// 게시물 검색 성공
class PostSearchSuccess extends SearchState {
  final List<Post> posts;
  final String query;
  final bool hasMore;

  const PostSearchSuccess({
    required this.posts,
    required this.query,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [posts, query, hasMore];

  PostSearchSuccess copyWith({
    List<Post>? posts,
    String? query,
    bool? hasMore,
  }) {
    return PostSearchSuccess(
      posts: posts ?? this.posts,
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 사용자 검색 성공
class UserSearchSuccess extends SearchState {
  final List<SocialUser> users;
  final String query;
  final bool hasMore;

  const UserSearchSuccess({
    required this.users,
    required this.query,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [users, query, hasMore];

  UserSearchSuccess copyWith({
    List<SocialUser>? users,
    String? query,
    bool? hasMore,
  }) {
    return UserSearchSuccess(
      users: users ?? this.users,
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// 해시태그 목록 로드 성공
class HashtagsLoaded extends SearchState {
  final List<String> hashtags;
  final bool isTrending;

  const HashtagsLoaded({
    required this.hashtags,
    this.isTrending = false,
  });

  @override
  List<Object?> get props => [hashtags, isTrending];
}

/// 검색 실패
class SearchError extends SearchState {
  final String message;

  const SearchError({required this.message});

  @override
  List<Object?> get props => [message];
}
