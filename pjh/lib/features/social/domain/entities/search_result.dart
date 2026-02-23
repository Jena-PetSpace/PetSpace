import 'package:equatable/equatable.dart';

import 'post.dart';
import '../../../auth/domain/entities/user.dart';

/// 통합 검색 결과
class SearchResult extends Equatable {
  final List<Post> posts;
  final List<User> users;
  final List<String> hashtags;
  final String query;
  final DateTime searchedAt;

  const SearchResult({
    required this.posts,
    required this.users,
    required this.hashtags,
    required this.query,
    required this.searchedAt,
  });

  bool get isEmpty => posts.isEmpty && users.isEmpty && hashtags.isEmpty;
  bool get isNotEmpty => !isEmpty;

  int get totalCount => posts.length + users.length + hashtags.length;

  @override
  List<Object?> get props => [
        posts,
        users,
        hashtags,
        query,
        searchedAt,
      ];
}

/// 해시태그 검색 결과 (통계 포함)
class HashtagSearchResult extends Equatable {
  final String hashtag;
  final int postCount;
  final List<Post> recentPosts;

  const HashtagSearchResult({
    required this.hashtag,
    required this.postCount,
    required this.recentPosts,
  });

  @override
  List<Object?> get props => [hashtag, postCount, recentPosts];
}
