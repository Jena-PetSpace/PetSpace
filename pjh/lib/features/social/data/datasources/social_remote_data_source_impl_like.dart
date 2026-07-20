part of 'social_remote_data_source.dart';

extension _SocialDsLike on SocialRemoteDataSourceImpl {
  Future<void> _likePost(String postId, String userId) async {
    try {
      _logger.debug('Liking post: $postId by $userId', tag: 'SocialDataSource');
      await supabaseClient.from('likes').upsert(
        {
          'post_id': postId,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,post_id',
        ignoreDuplicates: true,
      );
      await supabaseClient.rpc(
        'increment_post_likes',
        params: {'post_id': postId},
      );
      _logger.debug(
        'Successfully liked post: $postId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to like post',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('좋아요 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _unlikePost(String postId, String userId) async {
    try {
      _logger.debug(
        'Unliking post: $postId by $userId',
        tag: 'SocialDataSource',
      );
      final deleted = await supabaseClient
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .select();
      if (deleted.isNotEmpty) {
        await supabaseClient.rpc(
          'decrement_post_likes',
          params: {'post_id': postId},
        );
      }
      _logger.debug(
        'Successfully unliked post: $postId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to unlike post',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('좋아요 취소 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<bool> _isPostLiked(String postId, String userId) async {
    try {
      final response = await supabaseClient
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check like status',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      return false;
    }
  }

  Future<List<String>> _getPostLikes(String postId, int limit) async {
    try {
      _logger.debug('Getting post likes: $postId', tag: 'SocialDataSource');
      final response = await supabaseClient
          .from('likes')
          .select('user_id')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .limit(limit);
      final userIds =
          (response as List).map((json) => json['user_id'] as String).toList();
      _logger.debug('Found ${userIds.length} likes', tag: 'SocialDataSource');
      return userIds;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get post likes',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('좋아요 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<PostLikesPage> _getPostLikesPage({
    required String postId,
    required String currentUserId,
    PostLikesCursor? cursor,
    String query = '',
    int limit = 20,
  }) async {
    try {
      final pageSize = limit.clamp(1, 100).toInt();
      var queryBuilder = supabaseClient.from('likes').select('''
            id, user_id, created_at,
            users!likes_user_id_fkey!inner(
              id, display_name, username, photo_url
            )
          ''').eq('post_id', postId);

      if (cursor != null) {
        final createdAt = _quoteLikePostgrestValue(
          cursor.createdAt.toUtc().toIso8601String(),
        );
        final likeId = _quoteLikePostgrestValue(cursor.likeId);
        queryBuilder = queryBuilder.or(
          'created_at.lt.$createdAt,'
          'and(created_at.eq.$createdAt,id.lt.$likeId)',
        );
      }

      final normalizedQuery = query.trim().replaceFirst(RegExp(r'^@+'), '');
      if (normalizedQuery.isNotEmpty) {
        final pattern = _quoteLikePostgrestValue('*$normalizedQuery*');
        queryBuilder = queryBuilder.or(
          'display_name.ilike.$pattern,username.ilike.$pattern',
          referencedTable: 'users',
        );
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(pageSize + 1);
      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final visibleRows = rows.take(pageSize).toList();
      final userIds = visibleRows
          .map((row) => row['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty && id != currentUserId)
          .toSet()
          .toList();

      final followingIds = <String>{};
      if (currentUserId.isNotEmpty && userIds.isNotEmpty) {
        final follows = await supabaseClient
            .from('follows')
            .select('following_id')
            .eq('follower_id', currentUserId)
            .inFilter('following_id', userIds);
        followingIds.addAll(
          (follows as List)
              .map((row) => (row as Map)['following_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
      }

      final items = visibleRows.map((row) {
        final user = Map<String, dynamic>.from(row['users'] as Map);
        final userId = row['user_id']?.toString() ?? '';
        return PostLikeUser(
          likeId: row['id']?.toString() ?? '',
          userId: userId,
          displayName: user['display_name']?.toString() ?? '사용자',
          username: user['username']?.toString(),
          photoUrl: user['photo_url']?.toString(),
          relation: userId == currentUserId
              ? PostLikeRelation.self
              : followingIds.contains(userId)
                  ? PostLikeRelation.following
                  : PostLikeRelation.notFollowing,
        );
      }).toList();

      PostLikesCursor? nextCursor;
      if (visibleRows.isNotEmpty) {
        final last = visibleRows.last;
        nextCursor = PostLikesCursor(
          createdAt: DateTime.parse(last['created_at'] as String),
          likeId: last['id'] as String,
        );
      }
      return PostLikesPage(
        items: items,
        hasMore: rows.length > pageSize,
        nextCursor: nextCursor,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to get paged post likes',
        error: error,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('좋아요 목록을 불러오지 못했습니다.');
    }
  }

  String _quoteLikePostgrestValue(String value) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
