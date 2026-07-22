part of 'social_remote_data_source.dart';

extension _SocialDsSearch on SocialRemoteDataSourceImpl {
  Future<List<Post>> _searchPosts({
    required String query,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      _logger.debug('Searching posts with query: $query, limit: $limit',
          tag: 'SocialDataSource');
      var baseQuery = supabaseClient
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .or('caption.ilike.%$query%,hashtags.cs.{$query}');
      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();
        baseQuery =
            baseQuery.filter('created_at', 'lt', lastPost['created_at']);
      }
      final response =
          await baseQuery.order('created_at', ascending: false).limit(limit);
      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();
      _logger.debug('Found ${posts.length} posts', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to search posts',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 검색 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<Post>> _searchPostsByHashtag({
    required String hashtag,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      _logger.debug('Searching posts by hashtag: $hashtag, limit: $limit',
          tag: 'SocialDataSource');
      var baseQuery = supabaseClient
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .contains('hashtags', [hashtag]);
      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();
        baseQuery =
            baseQuery.filter('created_at', 'lt', lastPost['created_at']);
      }
      final response =
          await baseQuery.order('created_at', ascending: false).limit(limit);
      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();
      _logger.debug('Found ${posts.length} posts with hashtag: $hashtag',
          tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to search posts by hashtag',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('해시태그 검색 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<String>> _getPopularHashtags({int limit = 20}) async {
    try {
      _logger.debug('Fetching popular hashtags, limit: $limit',
          tag: 'SocialDataSource');
      final response =
          await supabaseClient.rpc('get_popular_hashtags', params: {
        'limit_count': limit,
      });
      if (response == null) {
        return await _hashtagClientFallback(limit: limit);
      }
      final hashtags =
          (response as List).map((item) => item['hashtag'].toString()).toList();
      _logger.debug('Found ${hashtags.length} popular hashtags',
          tag: 'SocialDataSource');
      return hashtags;
    } catch (e, stackTrace) {
      _logger.error('Failed to get popular hashtags',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      return [];
    }
  }

  Future<List<String>> _getTrendingHashtags(
      {int limit = 10, int days = 7}) async {
    try {
      _logger.debug('Fetching trending hashtags, limit: $limit, days: $days',
          tag: 'SocialDataSource');
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      try {
        final response =
            await supabaseClient.rpc('get_trending_hashtags', params: {
          'limit_count': limit,
          'days_ago': days,
        });
        if (response != null) {
          final hashtags = (response as List)
              .map((item) => item['hashtag'].toString())
              .toList();
          _logger.debug('Found ${hashtags.length} trending hashtags',
              tag: 'SocialDataSource');
          return hashtags;
        }
      } catch (rpcError) {
        _logger.debug('RPC not available, using client-side calculation',
            tag: 'SocialDataSource');
      }
      return await _hashtagClientFallback(
          limit: limit, since: cutoffDate.toIso8601String());
    } catch (e, stackTrace) {
      _logger.error('Failed to get trending hashtags',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      return [];
    }
  }

  Future<List<String>> _hashtagClientFallback(
      {required int limit, String? since}) async {
    var filterQ = supabaseClient.from('posts').select('hashtags');
    if (since != null) filterQ = filterQ.gte('created_at', since);
    final q = filterQ.order('created_at', ascending: false).limit(1000);
    final posts = await q;
    final Map<String, int> counts = {};
    for (final post in posts as List) {
      final tags = post['hashtags'] as List?;
      if (tags != null) {
        for (final tag in tags) {
          final t = tag.toString();
          counts[t] = (counts[t] ?? 0) + 1;
        }
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  Future<List<Post>> _getRecommendedPosts(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final response =
          await supabaseClient.rpc('get_recommended_posts', params: {
        'p_user_id': userId,
        'p_limit': limit,
        'p_offset': offset,
      });
      return (response as List).map((json) {
        final model = PostModel.fromJson(json as Map<String, dynamic>);
        final entity = model.toEntity();
        return entity.copyWith(
          recommendationScore: json['recommendation_score'] as int?,
        );
      }).toList();
    } catch (e, st) {
      _logger.error('getRecommendedPosts 실패',
          error: e, stackTrace: st, tag: 'SocialDataSource');
      throw Exception('추천 게시물 조회 실패: $e');
    }
  }

  Future<List<Post>> _getPostsByHashtag({
    required String hashtag,
    String? userId,
    String sort = 'popular',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response =
          await supabaseClient.rpc('get_posts_by_hashtag', params: {
        'p_hashtag': hashtag,
        'p_user_id': userId,
        'p_sort': sort,
        'p_limit': limit,
        'p_offset': offset,
      });
      return (response as List)
          .map((json) =>
              PostModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();
    } catch (e, st) {
      _logger.error('getPostsByHashtag 실패',
          error: e, stackTrace: st, tag: 'SocialDataSource');
      throw Exception('해시태그 게시물 조회 실패: $e');
    }
  }

  Future<List<Post>> _getPostsByLocation({
    required double lat,
    required double lng,
    int radiusM = 50,
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response =
          await supabaseClient.rpc('get_posts_by_location', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_m': radiusM,
        'p_user_id': userId,
        'p_limit': limit,
        'p_offset': offset,
      });
      return (response as List)
          .map((json) =>
              PostModel.fromJson(json as Map<String, dynamic>).toEntity())
          .toList();
    } catch (e, st) {
      _logger.error('getPostsByLocation 실패',
          error: e, stackTrace: st, tag: 'SocialDataSource');
      throw Exception('위치 게시물 조회 실패: $e');
    }
  }

  Future<List<BookmarkCollection>> _getBookmarkCollections(
      String userId) async {
    try {
      final response = await supabaseClient
          .from('bookmark_collections')
          .select('id, user_id, name, emoji, created_at, updated_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => BookmarkCollection(
                id: json['id'] as String,
                userId: json['user_id'] as String,
                name: json['name'] as String,
                emoji: json['emoji'] as String? ?? '📁',
                createdAt: DateTime.parse(json['created_at'] as String),
                updatedAt: DateTime.parse(json['updated_at'] as String),
              ))
          .toList();
    } catch (e, st) {
      _logger.error('getBookmarkCollections 실패',
          error: e, stackTrace: st, tag: 'SocialDataSource');
      throw Exception('북마크 컬렉션 조회 실패: $e');
    }
  }

  Future<BookmarkCollection> _createBookmarkCollection({
    required String userId,
    required String name,
    String emoji = '📁',
  }) async {
    try {
      final response = await supabaseClient
          .from('bookmark_collections')
          .insert({'user_id': userId, 'name': name, 'emoji': emoji})
          .select()
          .single();
      return BookmarkCollection(
        id: response['id'] as String,
        userId: response['user_id'] as String,
        name: response['name'] as String,
        emoji: response['emoji'] as String? ?? '📁',
        createdAt: DateTime.parse(response['created_at'] as String),
        updatedAt: DateTime.parse(response['updated_at'] as String),
      );
    } catch (e, st) {
      _logger.error('createBookmarkCollection 실패',
          error: e, stackTrace: st, tag: 'SocialDataSource');
      throw Exception('북마크 컬렉션 생성 실패: $e');
    }
  }

  Future<void> _deleteBookmarkCollection({
    required String collectionId,
    required String userId,
  }) async {
    try {
      final response = await supabaseClient
          .from('bookmark_collections')
          .delete()
          .eq('id', collectionId)
          .eq('user_id', userId)
          .select('id');
      if ((response as List).isEmpty) {
        throw StateError('collection-not-found');
      }
    } catch (e, st) {
      _logger.error('deleteBookmarkCollection 실패',
          error: e, stackTrace: st, tag: 'SocialDataSource');
      throw Exception('북마크 컬렉션 삭제 실패: $e');
    }
  }

  Future<void> _updateSavedPostCollection({
    required String postId,
    required String userId,
    String? collectionId,
  }) async {
    try {
      if (collectionId != null) {
        final owned = await supabaseClient
            .from('bookmark_collections')
            .select('id')
            .eq('id', collectionId)
            .eq('user_id', userId)
            .maybeSingle();
        if (owned == null) throw StateError('collection-not-owned');
      }
      final response = await supabaseClient
          .from('saved_posts')
          .update({'collection_id': collectionId})
          .eq('post_id', postId)
          .eq('user_id', userId)
          .select('id');
      if ((response as List).isEmpty) {
        throw StateError('saved-post-not-found');
      }
    } catch (e, st) {
      _logger.error('updateSavedPostCollection 실패',
          error: e, stackTrace: st, tag: 'SocialDataSource');
      throw Exception('북마크 컬렉션 이동 실패: $e');
    }
  }
}
