import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/post.dart';
import '../../domain/entities/social_user.dart';
import '../../domain/repositories/social_repository.dart';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SocialRepository repository;

  SearchBloc({required this.repository}) : super(const SearchInitial()) {
    on<SearchAllRequested>(_onSearchAllRequested);
    on<SearchPostsRequested>(_onSearchPostsRequested);
    on<SearchPostsByHashtagRequested>(_onSearchPostsByHashtagRequested);
    on<SearchUsersRequested>(_onSearchUsersRequested);
    on<GetPopularHashtagsRequested>(_onGetPopularHashtagsRequested);
    on<GetTrendingHashtagsRequested>(_onGetTrendingHashtagsRequested);
    on<ClearSearchRequested>(_onClearSearchRequested);
  }

  Future<void> _onSearchAllRequested(
    SearchAllRequested event,
    Emitter<SearchState> emit,
  ) async {
    emit(const SearchLoading());

    try {
      // 병렬로 게시물과 사용자 검색
      final results = await Future.wait([
        repository.searchPosts(query: event.query, limit: 20),
        repository.searchUsers(event.query),
        repository.getPopularHashtags(limit: 10),
      ]);

      final postsResult = results[0];
      final usersResult = results[1];
      final hashtagsResult = results[2];

      List<Post> posts = [];
      List<SocialUser> users = [];
      List<String> hashtags = [];

      postsResult.fold(
        (failure) => null, // 실패 시 빈 리스트 유지
        (data) => posts = data as List<Post>,
      );

      usersResult.fold(
        (failure) => null,
        (data) => users = data as List<SocialUser>,
      );

      hashtagsResult.fold(
        (failure) => null,
        (data) => hashtags = data as List<String>,
      );

      emit(SearchSuccess(
        posts: posts,
        users: users,
        hashtags: hashtags,
        query: event.query,
        hasMorePosts: posts.length >= 20,
        hasMoreUsers: users.length >= 20,
      ));
    } catch (e) {
      emit(SearchError(message: '검색 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  Future<void> _onSearchPostsRequested(
    SearchPostsRequested event,
    Emitter<SearchState> emit,
  ) async {
    // 더 보기인 경우 현재 상태 확인
    if (event.loadMore && state is PostSearchSuccess) {
      final currentState = state as PostSearchSuccess;
      if (!currentState.hasMore) return;

      final lastPostId = currentState.posts.isNotEmpty
          ? currentState.posts.last.id
          : null;

      final result = await repository.searchPosts(
        query: event.query,
        limit: 20,
        lastPostId: lastPostId,
      );

      result.fold(
        (failure) => emit(SearchError(message: failure.message)),
        (newPosts) {
          final updatedPosts = [...currentState.posts, ...newPosts];
          emit(PostSearchSuccess(
            posts: updatedPosts,
            query: event.query,
            hasMore: newPosts.length >= 20,
          ));
        },
      );
    } else {
      // 새로운 검색
      emit(const SearchLoading());

      final result = await repository.searchPosts(
        query: event.query,
        limit: 20,
      );

      result.fold(
        (failure) => emit(SearchError(message: failure.message)),
        (posts) => emit(PostSearchSuccess(
          posts: posts,
          query: event.query,
          hasMore: posts.length >= 20,
        )),
      );
    }
  }

  Future<void> _onSearchPostsByHashtagRequested(
    SearchPostsByHashtagRequested event,
    Emitter<SearchState> emit,
  ) async {
    // 더 보기인 경우 현재 상태 확인
    if (event.loadMore && state is PostSearchSuccess) {
      final currentState = state as PostSearchSuccess;
      if (!currentState.hasMore) return;

      final lastPostId = currentState.posts.isNotEmpty
          ? currentState.posts.last.id
          : null;

      final result = await repository.searchPostsByHashtag(
        hashtag: event.hashtag,
        limit: 20,
        lastPostId: lastPostId,
      );

      result.fold(
        (failure) => emit(SearchError(message: failure.message)),
        (newPosts) {
          final updatedPosts = [...currentState.posts, ...newPosts];
          emit(PostSearchSuccess(
            posts: updatedPosts,
            query: '#${event.hashtag}',
            hasMore: newPosts.length >= 20,
          ));
        },
      );
    } else {
      // 새로운 검색
      emit(const SearchLoading());

      final result = await repository.searchPostsByHashtag(
        hashtag: event.hashtag,
        limit: 20,
      );

      result.fold(
        (failure) => emit(SearchError(message: failure.message)),
        (posts) => emit(PostSearchSuccess(
          posts: posts,
          query: '#${event.hashtag}',
          hasMore: posts.length >= 20,
        )),
      );
    }
  }

  Future<void> _onSearchUsersRequested(
    SearchUsersRequested event,
    Emitter<SearchState> emit,
  ) async {
    if (event.loadMore && state is UserSearchSuccess) {
      final currentState = state as UserSearchSuccess;
      if (!currentState.hasMore) return;

      final result = await repository.searchUsers(event.query);

      result.fold(
        (failure) => emit(SearchError(message: failure.message)),
        (newUsers) {
          final updatedUsers = [...currentState.users, ...newUsers];
          emit(UserSearchSuccess(
            users: updatedUsers,
            query: event.query,
            hasMore: newUsers.length >= 20,
          ));
        },
      );
    } else {
      emit(const SearchLoading());

      final result = await repository.searchUsers(event.query);

      result.fold(
        (failure) => emit(SearchError(message: failure.message)),
        (users) => emit(UserSearchSuccess(
          users: users,
          query: event.query,
          hasMore: users.length >= 20,
        )),
      );
    }
  }

  Future<void> _onGetPopularHashtagsRequested(
    GetPopularHashtagsRequested event,
    Emitter<SearchState> emit,
  ) async {
    emit(const SearchLoading());

    final result = await repository.getPopularHashtags(limit: event.limit);

    result.fold(
      (failure) => emit(SearchError(message: failure.message)),
      (hashtags) => emit(HashtagsLoaded(
        hashtags: hashtags,
        isTrending: false,
      )),
    );
  }

  Future<void> _onGetTrendingHashtagsRequested(
    GetTrendingHashtagsRequested event,
    Emitter<SearchState> emit,
  ) async {
    emit(const SearchLoading());

    final result = await repository.getTrendingHashtags(
      limit: event.limit,
      days: event.days,
    );

    result.fold(
      (failure) => emit(SearchError(message: failure.message)),
      (hashtags) => emit(HashtagsLoaded(
        hashtags: hashtags,
        isTrending: true,
      )),
    );
  }

  void _onClearSearchRequested(
    ClearSearchRequested event,
    Emitter<SearchState> emit,
  ) {
    emit(const SearchInitial());
  }
}
