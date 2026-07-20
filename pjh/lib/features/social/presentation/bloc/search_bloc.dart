import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/follow.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/social_user.dart';
import '../../domain/repositories/social_repository.dart';

part 'search_event.dart';
part 'search_state.dart';

typedef CurrentUserIdProvider = String? Function();

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  static const int _pageSize = 20;

  final SocialRepository repository;
  final CurrentUserIdProvider currentUserIdProvider;
  int _generation = 0;
  final Set<SearchSection> _inFlightLoadMore = <SearchSection>{};
  Set<String>? _cachedFollowingIds;

  SearchBloc({
    required this.repository,
    required this.currentUserIdProvider,
  }) : super(const SearchState()) {
    on<LoadDiscoveryRequested>(_onLoadDiscovery);
    on<SearchAllRequested>(_onSearchAll);
    on<SearchPostsRequested>(_onSearchPosts);
    on<SearchPostsByHashtagRequested>(_onSearchByHashtag);
    on<SearchUsersRequested>(_onSearchUsers);
    on<GetPopularHashtagsRequested>(_onPopularHashtags);
    on<GetTrendingHashtagsRequested>(_onTrendingHashtags);
    on<SearchPostChanged>(_onPostChanged);
    on<SearchPostRemoved>(_onPostRemoved);
    on<SearchFollowingChanged>(_onFollowingChanged);
    on<ClearSearchRequested>(_onClear);
  }

  String _safeError(Failure failure) {
    if (failure is NetworkFailure) {
      return '네트워크 연결을 확인하고 다시 시도해주세요.';
    }
    return '검색 결과를 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  List<Post> _dedupePosts(Iterable<Post> posts) {
    final byId = <String, Post>{};
    for (final post in posts) {
      byId[post.id] = post;
    }
    return byId.values.toList();
  }

  List<SocialUser> _dedupeUsers(Iterable<SocialUser> users) {
    final byId = <String, SocialUser>{};
    for (final user in users) {
      byId[user.id] = user;
    }
    return byId.values.toList();
  }

  List<SocialUser> _sortByFollowing(
    List<SocialUser> users,
    Set<String> followingIds,
  ) {
    if (followingIds.isEmpty) return users;
    return [
      ...users.where((user) => followingIds.contains(user.id)),
      ...users.where((user) => !followingIds.contains(user.id)),
    ];
  }

  Future<Set<String>> _loadFollowingIds() async {
    final userId = currentUserIdProvider();
    if (userId == null || userId.isEmpty) return const {};
    final cached = _cachedFollowingIds;
    if (cached != null) return cached;

    final ids = <String>{};
    String? lastUserId;
    while (true) {
      final result = await repository.getFollowingPage(
        userId: userId,
        limit: 100,
        lastUserId: lastUserId,
      );
      List<Follow>? page;
      var failed = false;
      result.fold(
        (_) => failed = true,
        (items) => page = items,
      );
      final items = page;
      if (failed || items == null) return ids;
      if (items.isEmpty) break;

      ids.addAll(items.map((item) => item.followingId));
      final nextUserId = items.last.followingId;
      if (nextUserId == lastUserId) break;
      lastUserId = nextUserId;
      if (items.length < 100) break;
    }

    return _cachedFollowingIds = Set<String>.unmodifiable(ids);
  }

  Future<void> _onLoadDiscovery(
    LoadDiscoveryRequested event,
    Emitter<SearchState> emit,
  ) async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        query: '',
        generation: generation,
        loading: {...state.loading, SearchSection.discovery},
        errors: Map.of(state.errors)..remove(SearchSection.discovery),
      ),
    );

    final postsResult = await repository.getExplorePosts(limit: 12);
    final hashtagsResult = await repository.getTrendingHashtags(limit: 10);
    if (generation != _generation) return;

    final errors = Map<SearchSection, String>.of(state.errors);
    var posts = <Post>[];
    var hashtags = <String>[];
    postsResult.fold(
      (failure) => errors[SearchSection.discovery] = _safeError(failure),
      (value) => posts = _dedupePosts(value),
    );
    hashtagsResult.fold(
      (failure) => errors[SearchSection.hashtags] = _safeError(failure),
      (value) => hashtags = value,
    );
    emit(
      state.copyWith(
        discoveryPosts: posts,
        discoveryHashtags: hashtags,
        loading: {...state.loading}..remove(SearchSection.discovery),
        errors: errors,
      ),
    );
  }

  Future<void> _onSearchAll(
    SearchAllRequested event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      add(const ClearSearchRequested());
      return;
    }
    final generation = ++_generation;
    _cachedFollowingIds = null;
    emit(
      state.copyWith(
        query: query,
        generation: generation,
        posts: const [],
        users: const [],
        hashtags: const [],
        loading: const {
          SearchSection.all,
          SearchSection.posts,
          SearchSection.users,
          SearchSection.hashtags,
        },
        loadingMore: const {},
        errors: const {},
        loadMoreErrors: const {},
        hasMorePosts: false,
        hasMoreUsers: false,
        clearNextPostId: true,
        clearNextUserId: true,
      ),
    );

    final postsResult = await repository.searchPosts(
      query: query,
      limit: _pageSize,
    );
    if (generation != _generation) return;
    final usersResult = await repository.searchUsers(
      query,
      limit: _pageSize,
    );
    if (generation != _generation) return;
    final hashtagsResult = await repository.getPopularHashtags(limit: 50);
    final followingIds = await _loadFollowingIds();
    if (generation != _generation) return;

    final errors = <SearchSection, String>{};
    var posts = <Post>[];
    var users = <SocialUser>[];
    var hashtags = <String>[];
    var rawPostCount = 0;
    var rawUserCount = 0;
    String? nextPostId;
    postsResult.fold(
      (failure) => errors[SearchSection.posts] = _safeError(failure),
      (value) {
        rawPostCount = value.length;
        nextPostId = value.isEmpty ? null : value.last.id;
        posts = _dedupePosts(value);
      },
    );
    usersResult.fold(
      (failure) => errors[SearchSection.users] = _safeError(failure),
      (value) {
        rawUserCount = value.length;
        users = value;
      },
    );
    hashtagsResult.fold(
      (failure) => errors[SearchSection.hashtags] = _safeError(failure),
      (value) {
        final normalized = query.replaceFirst('#', '').toLowerCase();
        hashtags = value
            .where((tag) => tag.toLowerCase().contains(normalized))
            .toList();
      },
    );
    final nextUserId = users.isEmpty ? null : users.last.id;
    users = _sortByFollowing(_dedupeUsers(users), followingIds);
    if (errors.length == 3) {
      errors[SearchSection.all] = '검색 결과를 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
    }
    emit(
      state.copyWith(
        posts: posts,
        users: users,
        hashtags: hashtags,
        followingIds: followingIds,
        loading: const {},
        errors: errors,
        hasMorePosts: rawPostCount == _pageSize,
        hasMoreUsers: rawUserCount == _pageSize,
        nextPostId: nextPostId,
        clearNextPostId: nextPostId == null,
        nextUserId: nextUserId,
        clearNextUserId: nextUserId == null,
      ),
    );
  }

  Future<void> _onSearchPosts(
    SearchPostsRequested event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) return;
    if (event.loadMore) {
      await _loadMorePosts(
        emit: emit,
        query: query,
        hashtag: null,
      );
      return;
    }
    if (query != state.query) {
      add(SearchAllRequested(query: query));
      return;
    }
  }

  Future<void> _onSearchByHashtag(
    SearchPostsByHashtagRequested event,
    Emitter<SearchState> emit,
  ) async {
    final hashtag = event.hashtag.trim().replaceFirst('#', '');
    if (hashtag.isEmpty) return;
    if (event.loadMore) {
      await _loadMorePosts(
        emit: emit,
        query: '#$hashtag',
        hashtag: hashtag,
      );
      return;
    }
    final generation = ++_generation;
    emit(
      state.copyWith(
        query: '#$hashtag',
        generation: generation,
        posts: const [],
        users: const [],
        hashtags: const [],
        loading: const {SearchSection.posts},
        loadingMore: const {},
        errors: const {},
        loadMoreErrors: const {},
        hasMorePosts: false,
        hasMoreUsers: false,
        clearNextPostId: true,
        clearNextUserId: true,
      ),
    );
    final result = await repository.searchPostsByHashtag(
      hashtag: hashtag,
      limit: _pageSize,
    );
    if (generation != _generation) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          loading: {...state.loading}..remove(SearchSection.posts),
          errors: {
            ...state.errors,
            SearchSection.posts: _safeError(failure),
          },
        ),
      ),
      (value) {
        final rawPostCount = value.length;
        final nextPostId = value.isEmpty ? null : value.last.id;
        final posts = _dedupePosts(value);
        emit(
          state.copyWith(
            posts: posts,
            loading: {...state.loading}..remove(SearchSection.posts),
            errors: Map.of(state.errors)..remove(SearchSection.posts),
            hasMorePosts: rawPostCount == _pageSize,
            nextPostId: nextPostId,
            clearNextPostId: nextPostId == null,
          ),
        );
      },
    );
  }

  Future<void> _loadMorePosts({
    required Emitter<SearchState> emit,
    required String query,
    required String? hashtag,
  }) async {
    if (!state.hasMorePosts || !_inFlightLoadMore.add(SearchSection.posts)) {
      return;
    }
    final generation = _generation;
    emit(
      state.copyWith(
        loadingMore: {...state.loadingMore, SearchSection.posts},
        loadMoreErrors: Map.of(state.loadMoreErrors)
          ..remove(SearchSection.posts),
      ),
    );
    try {
      final result = hashtag == null
          ? await repository.searchPosts(
              query: query,
              limit: _pageSize,
              lastPostId: state.nextPostId,
            )
          : await repository.searchPostsByHashtag(
              hashtag: hashtag,
              limit: _pageSize,
              lastPostId: state.nextPostId,
            );
      if (generation != _generation) return;
      result.fold(
        (failure) => emit(
          state.copyWith(
            loadingMore: {...state.loadingMore}..remove(SearchSection.posts),
            loadMoreErrors: {
              ...state.loadMoreErrors,
              SearchSection.posts: _safeError(failure),
            },
          ),
        ),
        (value) {
          final merged = _dedupePosts([...state.posts, ...value]);
          emit(
            state.copyWith(
              posts: merged,
              loadingMore: {...state.loadingMore}..remove(SearchSection.posts),
              loadMoreErrors: Map.of(state.loadMoreErrors)
                ..remove(SearchSection.posts),
              hasMorePosts: value.length == _pageSize,
              nextPostId: value.isEmpty ? null : value.last.id,
              clearNextPostId: value.isEmpty,
            ),
          );
        },
      );
    } finally {
      _inFlightLoadMore.remove(SearchSection.posts);
    }
  }

  Future<void> _onSearchUsers(
    SearchUsersRequested event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) return;
    if (!event.loadMore) {
      if (query != state.query) add(SearchAllRequested(query: query));
      return;
    }
    if (!state.hasMoreUsers || !_inFlightLoadMore.add(SearchSection.users)) {
      return;
    }
    final generation = _generation;
    emit(
      state.copyWith(
        loadingMore: {...state.loadingMore, SearchSection.users},
        loadMoreErrors: Map.of(state.loadMoreErrors)
          ..remove(SearchSection.users),
      ),
    );
    try {
      final result = await repository.searchUsers(
        query,
        limit: _pageSize,
        lastUserId: state.nextUserId,
      );
      if (generation != _generation) return;
      result.fold(
        (failure) => emit(
          state.copyWith(
            loadingMore: {...state.loadingMore}..remove(SearchSection.users),
            loadMoreErrors: {
              ...state.loadMoreErrors,
              SearchSection.users: _safeError(failure),
            },
          ),
        ),
        (value) {
          final nextUserId = value.isEmpty ? null : value.last.id;
          final merged = _sortByFollowing(
            _dedupeUsers([...state.users, ...value]),
            state.followingIds,
          );
          emit(
            state.copyWith(
              users: merged,
              loadingMore: {...state.loadingMore}..remove(SearchSection.users),
              loadMoreErrors: Map.of(state.loadMoreErrors)
                ..remove(SearchSection.users),
              hasMoreUsers: value.length == _pageSize,
              nextUserId: nextUserId,
              clearNextUserId: nextUserId == null,
            ),
          );
        },
      );
    } finally {
      _inFlightLoadMore.remove(SearchSection.users);
    }
  }

  Future<void> _onPopularHashtags(
    GetPopularHashtagsRequested event,
    Emitter<SearchState> emit,
  ) async {
    await _loadHashtags(
      emit,
      repository.getPopularHashtags(limit: event.limit),
    );
  }

  Future<void> _onTrendingHashtags(
    GetTrendingHashtagsRequested event,
    Emitter<SearchState> emit,
  ) async {
    await _loadHashtags(
      emit,
      repository.getTrendingHashtags(limit: event.limit, days: event.days),
    );
  }

  Future<void> _loadHashtags(
    Emitter<SearchState> emit,
    Future<Either<Failure, List<String>>> request,
  ) async {
    final generation = _generation;
    emit(
      state.copyWith(
        loading: {...state.loading, SearchSection.hashtags},
        errors: Map.of(state.errors)..remove(SearchSection.hashtags),
      ),
    );
    final result = await request;
    if (generation != _generation) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          loading: {...state.loading}..remove(SearchSection.hashtags),
          errors: {
            ...state.errors,
            SearchSection.hashtags: _safeError(failure),
          },
        ),
      ),
      (value) => emit(
        state.copyWith(
          hashtags: value,
          loading: {...state.loading}..remove(SearchSection.hashtags),
          errors: Map.of(state.errors)..remove(SearchSection.hashtags),
        ),
      ),
    );
  }

  void _onPostChanged(SearchPostChanged event, Emitter<SearchState> emit) {
    List<Post> replace(List<Post> posts) => posts
        .map((post) => post.id == event.post.id ? event.post : post)
        .toList();
    emit(
      state.copyWith(
        posts: replace(state.posts),
        discoveryPosts: replace(state.discoveryPosts),
      ),
    );
  }

  void _onPostRemoved(SearchPostRemoved event, Emitter<SearchState> emit) {
    emit(
      state.copyWith(
        posts: state.posts.where((post) => post.id != event.postId).toList(),
        discoveryPosts: state.discoveryPosts
            .where((post) => post.id != event.postId)
            .toList(),
      ),
    );
  }

  void _onFollowingChanged(
    SearchFollowingChanged event,
    Emitter<SearchState> emit,
  ) {
    final followingIds = {...state.followingIds};
    if (event.isFollowing) {
      followingIds.add(event.userId);
    } else {
      followingIds.remove(event.userId);
    }
    _cachedFollowingIds = Set<String>.unmodifiable(followingIds);
    emit(
      state.copyWith(
        followingIds: followingIds,
        users: _sortByFollowing(state.users, followingIds),
      ),
    );
  }

  void _onClear(ClearSearchRequested event, Emitter<SearchState> emit) {
    final generation = ++_generation;
    emit(
      SearchState(
        discoveryPosts: state.discoveryPosts,
        discoveryHashtags: state.discoveryHashtags,
        generation: generation,
      ),
    );
  }
}
