part of 'search_bloc.dart';

enum SearchSection { discovery, all, posts, users, hashtags }

class SearchState extends Equatable {
  final String query;
  final List<Post> posts;
  final List<SocialUser> users;
  final List<String> hashtags;
  final List<Post> discoveryPosts;
  final List<String> discoveryHashtags;
  final Set<String> followingIds;
  final Set<SearchSection> loading;
  final Set<SearchSection> loadingMore;
  final Map<SearchSection, String> errors;
  final Map<SearchSection, String> loadMoreErrors;
  final bool hasMorePosts;
  final bool hasMoreUsers;
  final String? nextPostId;
  final String? nextUserId;
  final int generation;

  const SearchState({
    this.query = '',
    this.posts = const [],
    this.users = const [],
    this.hashtags = const [],
    this.discoveryPosts = const [],
    this.discoveryHashtags = const [],
    this.followingIds = const {},
    this.loading = const {},
    this.loadingMore = const {},
    this.errors = const {},
    this.loadMoreErrors = const {},
    this.hasMorePosts = false,
    this.hasMoreUsers = false,
    this.nextPostId,
    this.nextUserId,
    this.generation = 0,
  });

  bool isLoading(SearchSection section) => loading.contains(section);
  bool isLoadingMore(SearchSection section) => loadingMore.contains(section);
  String? errorFor(SearchSection section) => errors[section];
  String? loadMoreErrorFor(SearchSection section) => loadMoreErrors[section];

  SearchState copyWith({
    String? query,
    List<Post>? posts,
    List<SocialUser>? users,
    List<String>? hashtags,
    List<Post>? discoveryPosts,
    List<String>? discoveryHashtags,
    Set<String>? followingIds,
    Set<SearchSection>? loading,
    Set<SearchSection>? loadingMore,
    Map<SearchSection, String>? errors,
    Map<SearchSection, String>? loadMoreErrors,
    bool? hasMorePosts,
    bool? hasMoreUsers,
    String? nextPostId,
    bool clearNextPostId = false,
    String? nextUserId,
    bool clearNextUserId = false,
    int? generation,
  }) {
    return SearchState(
      query: query ?? this.query,
      posts: posts ?? this.posts,
      users: users ?? this.users,
      hashtags: hashtags ?? this.hashtags,
      discoveryPosts: discoveryPosts ?? this.discoveryPosts,
      discoveryHashtags: discoveryHashtags ?? this.discoveryHashtags,
      followingIds: followingIds ?? this.followingIds,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      errors: errors ?? this.errors,
      loadMoreErrors: loadMoreErrors ?? this.loadMoreErrors,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      hasMoreUsers: hasMoreUsers ?? this.hasMoreUsers,
      nextPostId: clearNextPostId ? null : (nextPostId ?? this.nextPostId),
      nextUserId: clearNextUserId ? null : (nextUserId ?? this.nextUserId),
      generation: generation ?? this.generation,
    );
  }

  @override
  List<Object?> get props => [
        query,
        posts,
        users,
        hashtags,
        discoveryPosts,
        discoveryHashtags,
        followingIds,
        loading,
        loadingMore,
        errors,
        loadMoreErrors,
        hasMorePosts,
        hasMoreUsers,
        nextPostId,
        nextUserId,
        generation,
      ];
}
