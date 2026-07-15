part of 'social_remote_data_source.dart';

extension _SocialDsFollow on SocialRemoteDataSourceImpl {
  Future<void> _followUser(String followerId, String followingId) async {
    try {
      _logger.debug('Following user: $followerId following $followingId',
          tag: 'SocialDataSource');
      await supabaseClient.from('follows').insert({
        'follower_id': followerId,
        'following_id': followingId,
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug('Successfully followed user: $followingId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to follow user',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로우 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _unfollowUser(String followerId, String followingId) async {
    try {
      _logger.debug('Unfollowing user: $followerId unfollowing $followingId',
          tag: 'SocialDataSource');
      await supabaseClient
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);
      _logger.debug('Successfully unfollowed user: $followingId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to unfollow user',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('언팔로우 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<bool> _isFollowing(String followerId, String followingId) async {
    try {
      final response = await supabaseClient
          .from('follows')
          .select('id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();
      return response != null;
    } catch (e, stackTrace) {
      _logger.error('Failed to check following status',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      return false;
    }
  }

  Future<List<SocialUser>> _getFollowers(
      String userId, int limit, String? lastUserId,
      {String query = ''}) async {
    try {
      _logger.debug('Getting followers for user: $userId',
          tag: 'SocialDataSource');
      final cursor = await _getFollowCursor(
        ownerColumn: 'following_id',
        ownerId: userId,
        memberColumn: 'follower_id',
        lastUserId: lastUserId,
      );
      if (lastUserId != null && cursor == null) return [];

      var queryBuilder = supabaseClient.from('follows').select('''
            id, created_at, follower_id,
            users!follows_follower_id_fkey!inner(
              id, display_name, email, username, photo_url, bio, created_at, updated_at
            )
          ''').eq('following_id', userId);
      if (cursor != null) {
        queryBuilder = queryBuilder.or(_followCursorFilter(cursor));
      }
      final normalizedQuery = _normalizeFollowQuery(query);
      if (normalizedQuery.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          _followUserSearchFilter(normalizedQuery),
          referencedTable: 'users',
        );
      }
      final response = await queryBuilder
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);
      final followers = (response as List).map((json) {
        final userData = json['users'];
        return SocialUserModel(
          id: userData['id'] ?? '',
          displayName: userData['display_name'] ?? '',
          email: userData['email'] ?? '',
          username: userData['username'],
          profileImageUrl: userData['photo_url'],
          bio: userData['bio'],
          createdAt: userData['created_at'] != null
              ? DateTime.parse(userData['created_at'])
              : DateTime.now(),
          updatedAt: userData['updated_at'] != null
              ? DateTime.parse(userData['updated_at'])
              : DateTime.now(),
        ).toEntity();
      }).toList();
      _logger.debug('Found ${followers.length} followers',
          tag: 'SocialDataSource');
      return followers;
    } catch (e, stackTrace) {
      _logger.error('Failed to get followers',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로워 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<SocialUser>> _getFollowing(
      String userId, int limit, String? lastUserId,
      {String query = ''}) async {
    try {
      _logger.debug('Getting following for user: $userId',
          tag: 'SocialDataSource');
      final cursor = await _getFollowCursor(
        ownerColumn: 'follower_id',
        ownerId: userId,
        memberColumn: 'following_id',
        lastUserId: lastUserId,
      );
      if (lastUserId != null && cursor == null) return [];

      var queryBuilder = supabaseClient.from('follows').select('''
            id, created_at, following_id,
            users!follows_following_id_fkey!inner(
              id, display_name, email, username, photo_url, bio, created_at, updated_at
            )
          ''').eq('follower_id', userId);
      if (cursor != null) {
        queryBuilder = queryBuilder.or(_followCursorFilter(cursor));
      }
      final normalizedQuery = _normalizeFollowQuery(query);
      if (normalizedQuery.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          _followUserSearchFilter(normalizedQuery),
          referencedTable: 'users',
        );
      }
      final response = await queryBuilder
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);
      final following = (response as List).map((json) {
        final userData = json['users'];
        return SocialUserModel(
          id: userData['id'] ?? '',
          displayName: userData['display_name'] ?? '',
          email: userData['email'] ?? '',
          username: userData['username'],
          profileImageUrl: userData['photo_url'],
          bio: userData['bio'],
          createdAt: userData['created_at'] != null
              ? DateTime.parse(userData['created_at'])
              : DateTime.now(),
          updatedAt: userData['updated_at'] != null
              ? DateTime.parse(userData['updated_at'])
              : DateTime.now(),
        ).toEntity();
      }).toList();
      _logger.debug('Found ${following.length} following',
          tag: 'SocialDataSource');
      return following;
    } catch (e, stackTrace) {
      _logger.error('Failed to get following',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로잉 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> _getFollowCursor({
    required String ownerColumn,
    required String ownerId,
    required String memberColumn,
    required String? lastUserId,
  }) async {
    if (lastUserId == null || lastUserId.isEmpty) return null;
    final response = await supabaseClient
        .from('follows')
        .select('id, created_at')
        .eq(ownerColumn, ownerId)
        .eq(memberColumn, lastUserId)
        .maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  }

  String _followCursorFilter(Map<String, dynamic> cursor) {
    final createdAt =
        _quotePostgrestValue(cursor['created_at']?.toString() ?? '');
    final id = _quotePostgrestValue(cursor['id']?.toString() ?? '');
    return 'created_at.lt.$createdAt,and(created_at.eq.$createdAt,id.lt.$id)';
  }

  String _followUserSearchFilter(String query) {
    final pattern = _quotePostgrestValue('*$query*');
    return 'display_name.ilike.$pattern,username.ilike.$pattern';
  }

  String _normalizeFollowQuery(String query) =>
      query.trim().replaceFirst(RegExp(r'^@+'), '');

  String _quotePostgrestValue(String value) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}
