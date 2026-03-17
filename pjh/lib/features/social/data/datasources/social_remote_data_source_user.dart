part of 'social_remote_data_source.dart';

  Future<SocialUser> createUser(SocialUser user) async {
    try {
      _logger.debug('Creating user: ${user.id}', tag: 'SocialDataSource');

      final userModel = SocialUserModel.fromEntity(user);

      final response = await supabaseClient
          .from('users')
          .insert({
            'id': userModel.id,
            'display_name': userModel.displayName,
            'email': userModel.email,
            'username': userModel.username,
            'photo_url': userModel.profileImageUrl,
            'bio': userModel.bio,
            'created_at': userModel.createdAt.toIso8601String(),
            'updated_at': userModel.updatedAt.toIso8601String(),
          })
          .select()
          .single();

      final createdUser = SocialUserModel(
        id: response['id'] ?? '',
        displayName: response['display_name'] ?? '',
        email: response['email'] ?? '',
        username: response['username'],
        profileImageUrl: response['photo_url'],
        bio: response['bio'],
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        updatedAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : DateTime.now(),
      ).toEntity();

      _logger.debug('Successfully created user: ${createdUser.displayName}', tag: 'SocialDataSource');
      return createdUser;
    } catch (e, stackTrace) {
      _logger.error('Failed to create user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 생성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<SocialUser> getUser(String userId) async {
    try {
      _logger.debug('Getting user: $userId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();

      final user = SocialUserModel(
        id: response['id'] ?? '',
        displayName: response['display_name'] ?? '',
        email: response['email'] ?? '',
        username: response['username'],
        profileImageUrl: response['photo_url'],
        bio: response['bio'],
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        updatedAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : DateTime.now(),
      ).toEntity();

      _logger.debug('Successfully fetched user: ${user.displayName}', tag: 'SocialDataSource');
      return user;
    } catch (e, stackTrace) {
      _logger.error('Failed to get user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 정보를 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<SocialUser> updateUser(SocialUser user) async {
    try {
      _logger.debug('Updating user: ${user.id}', tag: 'SocialDataSource');

      final userModel = SocialUserModel.fromEntity(user);

      final response = await supabaseClient
          .from('users')
          .update({
            'display_name': userModel.displayName,
            'username': userModel.username,
            'photo_url': userModel.profileImageUrl,
            'bio': userModel.bio,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id)
          .select()
          .single();

      final updatedUser = SocialUserModel(
        id: response['id'] ?? '',
        displayName: response['display_name'] ?? '',
        email: response['email'] ?? '',
        username: response['username'],
        profileImageUrl: response['photo_url'],
        bio: response['bio'],
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        updatedAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : DateTime.now(),
      ).toEntity();

      _logger.debug('Successfully updated user: ${updatedUser.displayName}', tag: 'SocialDataSource');
      return updatedUser;
    } catch (e, stackTrace) {
      _logger.error('Failed to update user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 정보 업데이트 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      _logger.debug('Deleting user: $userId', tag: 'SocialDataSource');

      await supabaseClient
          .from('users')
          .delete()
          .eq('id', userId);

      _logger.debug('Successfully deleted user: $userId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<SocialUser>> searchUsers(String query, int limit, String? lastUserId) async {
    try {
      _logger.debug('Searching users: $query', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('users')
          .select('*')
          .or('display_name.ilike.%$query%,username.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      final users = (response as List).map((json) {
        return SocialUserModel(
          id: json['id'] ?? '',
          displayName: json['display_name'] ?? '',
          email: json['email'] ?? '',
          username: json['username'],
          profileImageUrl: json['photo_url'],
          bio: json['bio'],
          createdAt: json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
          updatedAt: json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
        ).toEntity();
      }).toList();

      _logger.debug('Found ${users.length} users matching "$query"', tag: 'SocialDataSource');
      return users;
    } catch (e, stackTrace) {
      _logger.error('Failed to search users', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 검색 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
