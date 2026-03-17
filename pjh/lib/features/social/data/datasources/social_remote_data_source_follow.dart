part of 'social_remote_data_source.dart';

  Future<void> followUser(String followerId, String followingId) async {
    try {
      _logger.debug('Following user: $followerId following $followingId', tag: 'SocialDataSource');

      // follows 테이블에 관계 추가
      await supabaseClient.from('follows').insert({
        'follower_id': followerId,
        'following_id': followingId,
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully followed user: $followingId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to follow user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로우 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      _logger.debug('Unfollowing user: $followerId unfollowing $followingId', tag: 'SocialDataSource');

      // follows 테이블에서 관계 제거
      await supabaseClient
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);

      _logger.debug('Successfully unfollowed user: $followingId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to unfollow user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('언팔로우 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      _logger.debug('Checking if following: $followerId following $followingId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('follows')
          .select('id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      _logger.error('Failed to check following status', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      return false;
    }
  }

  @override
  Future<List<SocialUser>> getFollowers(String userId, int limit, String? lastUserId) async {
    try {
      _logger.debug('Getting followers for user: $userId', tag: 'SocialDataSource');

      var queryBuilder = supabaseClient
          .from('follows')
          .select('''
            follower_id,
            users!follows_follower_id_fkey(
              id,
              display_name,
              email,
              username,
              photo_url,
              bio,
              created_at,
              updated_at
            )
          ''')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final response = await queryBuilder;

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

      _logger.debug('Found ${followers.length} followers', tag: 'SocialDataSource');
      return followers;
    } catch (e, stackTrace) {
      _logger.error('Failed to get followers', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로워 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<SocialUser>> getFollowing(String userId, int limit, String? lastUserId) async {
    try {
      _logger.debug('Getting following for user: $userId', tag: 'SocialDataSource');

      var queryBuilder = supabaseClient
          .from('follows')
          .select('''
            following_id,
            users!follows_following_id_fkey(
              id,
              display_name,
              email,
              username,
              photo_url,
              bio,
              created_at,
              updated_at
            )
          ''')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final response = await queryBuilder;

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

      _logger.debug('Found ${following.length} following', tag: 'SocialDataSource');
      return following;
    } catch (e, stackTrace) {
      _logger.error('Failed to get following', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로잉 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
