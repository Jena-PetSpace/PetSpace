part of 'social_remote_data_source.dart';

extension _SocialDsPost on SocialRemoteDataSourceImpl {
  Future<Post> _createPost(Post post, List<File> images) async {
    String? insertedId;
    try {
      _logger.debug('Creating post: ${post.id}', tag: 'SocialDataSource');
      final postModel = PostModel.fromEntity(post);
      final insertData = postModel.toJson();
      insertData['image_urls'] = <String>[];
      insertData.remove('image_url');
      _logger.debug('Insert payload post_type: ${insertData['post_type']}',
          tag: 'SocialDataSource');
      final insertResponse = await supabaseClient
          .from('posts')
          .insert(insertData)
          .select('id')
          .single();
      insertedId = insertResponse['id'] as String;
      _logger.debug('Post row created: $insertedId', tag: 'SocialDataSource');
      List<String> uploadedUrls = [];
      if (images.isNotEmpty) {
        uploadedUrls = await _uploadPostImages(post.authorId, insertedId, images);
      }
      final updateData = <String, dynamic>{
        'image_urls': uploadedUrls,
        if (uploadedUrls.isNotEmpty) 'image_url': uploadedUrls.first,
        'post_type': postModel.postType,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final response = await supabaseClient
          .from('posts')
          .update(updateData)
          .eq('id', insertedId)
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .single();
      _logger.debug('Post created successfully: ${response['id']}',
          tag: 'SocialDataSource');
      return PostModel.fromJson(response).toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to create post',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      if (insertedId != null) {
        try {
          await supabaseClient
              .from('posts')
              .update({'deleted_at': DateTime.now().toIso8601String()})
              .eq('id', insertedId);
        } catch (_) {}
      }
      throw Exception('게시물 작성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<String>> _uploadPostImages(
      String userId, String postId, List<File> files) async {
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = file.path.split('.').last.toLowerCase();
      final path = 'posts/$userId/$postId/$i.$ext';
      await supabaseClient.storage
          .from('images')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));
      final url = supabaseClient.storage.from('images').getPublicUrl(path);
      urls.add(url);
    }
    _logger.debug('Uploaded ${urls.length} images for post $postId',
        tag: 'SocialDataSource');
    return urls;
  }

  Future<void> _deletePostImages(String userId, String postId) async {
    try {
      final list = await supabaseClient.storage
          .from('images')
          .list(path: 'posts/$userId/$postId');
      if (list.isNotEmpty) {
        final paths =
            list.map((f) => 'posts/$userId/$postId/${f.name}').toList();
        await supabaseClient.storage.from('images').remove(paths);
      }
      _logger.debug('Deleted images for post $postId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete post images',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
    }
  }

  Future<String> _uploadCoverImage(String userId, File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = 'users/$userId/cover.$ext';
    await supabaseClient.storage
        .from('images')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));
    final url = supabaseClient.storage.from('images').getPublicUrl(path);
    final cacheBusted = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    _logger.debug('Uploaded cover image for user $userId',
        tag: 'SocialDataSource');
    return cacheBusted;
  }

  Future<Post> _getPost(String postId) async {
    try {
      _logger.debug('Getting post: $postId', tag: 'SocialDataSource');
      final response = await supabaseClient
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .eq('id', postId)
          .single();
      final post = PostModel.fromJson(response).toEntity();
      _logger.debug('Successfully fetched post: $postId',
          tag: 'SocialDataSource');
      return post;
    } catch (e, stackTrace) {
      _logger.error('Failed to get post',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> _getPostDetail(String postId) async {
    try {
      final response = await supabaseClient
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .eq('id', postId)
          .maybeSingle();
      return response;
    } catch (e, stackTrace) {
      _logger.error('Failed to get post detail',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 상세 조회 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> _getUserPostsFiltered({
    required String authorId,
    String? petId,
    String? beforeCreatedAt,
    int limit = 30,
  }) async {
    var query = supabaseClient
        .from('posts')
        .select('id, image_url, image_urls, caption, post_type, created_at, pet_id')
        .eq('author_id', authorId)
        .isFilter('deleted_at', null);
    if (petId != null) query = query.eq('pet_id', petId);
    if (beforeCreatedAt != null) {
      query = query.lt('created_at', beforeCreatedAt);
    }
    final rows =
        await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _getCommunityPosts({
    String? category,
    int limit = 30,
    DateTime? beforeCreatedAt,
  }) async {
    var query = supabaseClient
        .from('posts')
        .select(
            'id, author_id, caption, hashtags, category, likes_count, comments_count, created_at, users!posts_author_id_fkey(display_name, photo_url)')
        .isFilter('deleted_at', null)
        // 커뮤니티(Q&A) 글만 — 사진 글이 Q&A 목록에 새는 오염 차단
        .eq('post_type', 'community')
        // 매거진은 별도 노출 경로 → Q&A에서 제외(안전장치 유지)
        .not('hashtags', 'cs', '{"magazine"}');
    // 카테고리 필터는 hashtags 역추론이 아닌 category 컬럼 기준
    if (category != null) query = query.eq('category', category);
    // 키셋 페이지네이션: 마지막 글의 created_at 이전 글만 (사진 피드와 동일 방식)
    if (beforeCreatedAt != null) {
      query = query.lt('created_at', beforeCreatedAt.toIso8601String());
    }
    final response =
        await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _getSavedPostsRaw(
    String userId, {
    int limit = 30,
    String? beforeSavedAt,
  }) async {
    var query = supabaseClient
        .from('saved_posts')
        .select('post_id, created_at, posts(id, image_url, caption, author_id)')
        .eq('user_id', userId);
    // 키셋 페이지네이션: 저장 시각(saved_posts.created_at) 기준. 내 글 커서와 동일 방식.
    if (beforeSavedAt != null) {
      query = query.lt('created_at', beforeSavedAt);
    }
    final response =
        await query.order('created_at', ascending: false).limit(limit);
    return (response as List)
        .map((e) {
          final post = e['posts'] as Map<String, dynamic>?;
          if (post == null) return null;
          // 저장 시각을 커서로 쓰도록 post 맵에 주입(post 자체 created_at과 구분).
          return {...post, 'saved_at': e['created_at']};
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Set<String>> _getEarnedBadgeIds(String userId) async {
    final res = await supabaseClient
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId);
    return Set<String>.from(
        (res as List).map((r) => r['badge_id'] as String));
  }

  Future<void> _checkAndAwardBadges(String userId) async {
    final existing = await supabaseClient
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId);
    final earnedIds = Set<String>.from(
        (existing as List).map((r) => r['badge_id'] as String));
    final toAward = <String>[];
    if (!earnedIds.contains('first_analysis')) {
      final analyses = await supabaseClient
          .from('emotion_history')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      if ((analyses as List).isNotEmpty) toAward.add('first_analysis');
    }
    if (!earnedIds.contains('streak_7')) {
      final pets = await supabaseClient
          .from('pets')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      if ((pets as List).isNotEmpty) toAward.add('streak_7');
    }
    if (toAward.isNotEmpty) {
      await supabaseClient.from('user_badges').insert(
            toAward
                .map((id) => {
                      'user_id': userId,
                      'badge_id': id,
                      'earned_at': DateTime.now().toIso8601String(),
                    })
                .toList(),
          );
    }
  }

  Future<List<Map<String, dynamic>>> _getPointTransactions(
      String userId) async {
    final response = await supabaseClient
        .from('point_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _getBlockedUsersDetailed(
      String blockerId) async {
    final response = await supabaseClient
        .from('user_blocks')
        .select(
            'blocked_id, users!user_blocks_blocked_id_fkey(display_name, photo_url)')
        .eq('blocker_id', blockerId)
        .limit(100);
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<int> _getUserPoints(String userId) async {
    final res = await supabaseClient
        .from('user_points')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    return (res?['balance'] as int?) ?? 0;
  }

  Future<bool> _hasQuestActivityToday({
    required String userId,
    required String questType,
  }) async {
    final todayStart = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    final iso = todayStart.toIso8601String();
    switch (questType) {
      case 'analyze':
        final rows = await supabaseClient
            .from('emotion_history')
            .select('id')
            .eq('user_id', userId)
            .gte('created_at', iso)
            .limit(1);
        return (rows as List).isNotEmpty;
      case 'post':
        final rows = await supabaseClient
            .from('posts')
            .select('id')
            .eq('author_id', userId)
            .isFilter('deleted_at', null)
            .gte('created_at', iso)
            .limit(1);
        return (rows as List).isNotEmpty;
      case 'like':
        final rows = await supabaseClient
            .from('likes')
            .select('id')
            .eq('user_id', userId)
            .gte('created_at', iso)
            .limit(1);
        return (rows as List).isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _incrementUserPoints({
    required String userId,
    required int points,
  }) async {
    // 보안(세션1 1-B): 서버 RPC가 적립 대상을 auth.uid()로 강제하므로 p_user_id는 무시된다.
    // (PostgREST 함수 시그니처 매칭을 위해 키 자체는 유지)
    await supabaseClient.rpc('increment_user_points', params: {
      'p_user_id': userId,
      'p_points': points,
    });
  }

  /// 뱃지 멱등 지급. 이미 보유면 false, 신규 지급이면 true.
  Future<bool> _awardBadgeIfAbsent({
    required String userId,
    required String badgeId,
  }) async {
    final existing = await supabaseClient
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId)
        .eq('badge_id', badgeId)
        .limit(1);
    if ((existing as List).isNotEmpty) return false;
    await supabaseClient.from('user_badges').insert({
      'user_id': userId,
      'badge_id': badgeId,
      'earned_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<int> _getUserStreak(String userId) async {
    try {
      final res = await supabaseClient
          .rpc('get_user_streak', params: {'p_user_id': userId});
      return (res as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>?> _getNotificationPreferences(
      String userId) async {
    return await supabaseClient
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<void> _upsertNotificationPreference({
    required String userId,
    required String column,
    required bool value,
  }) async {
    await supabaseClient.from('notification_preferences').upsert({
      'user_id': userId,
      column: value,
    });
  }

  Future<List<Post>> _getUserPosts(
      String userId, int limit, String? lastPostId,
      {DateTime? lastCreatedAt}) async {
    try {
      _logger.debug('Getting user posts: $userId', tag: 'SocialDataSource');
      var query = supabaseClient
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .eq('author_id', userId);
      if (lastCreatedAt != null) {
        query = query.lt('created_at', lastCreatedAt.toIso8601String());
      } else if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .maybeSingle();
        if (lastPost != null) {
          query = query.lt('created_at', lastPost['created_at']);
        }
      }
      final response =
          await query.order('created_at', ascending: false).limit(limit);
      final rawPosts =
          (response as List).map((json) => PostModel.fromJson(json)).toList();
      if (rawPosts.isEmpty) return [];
      final postIds = rawPosts.map((p) => p.id).toList();
      final likedRes = await supabaseClient
          .from('likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      final savedRes = await supabaseClient
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      final likedSet = {
        for (final r in likedRes as List) r['post_id'] as String
      };
      final savedSet = {
        for (final r in savedRes as List) r['post_id'] as String
      };
      final posts = rawPosts
          .map((m) => m
              .copyWith(
                isLikedByCurrentUser: likedSet.contains(m.id),
                isSavedByCurrentUser: savedSet.contains(m.id),
              )
              .toEntity())
          .toList();
      _logger.debug('Found ${posts.length} posts for user',
          tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to get user posts',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<Post>> _getFeedPosts(
      String userId, int limit, String? lastPostId,
      {DateTime? lastCreatedAt, bool followingOnly = false}) async {
    try {
      _logger.debug(
          'Getting feed posts for user: $userId (followingOnly: $followingOnly)',
          tag: 'SocialDataSource');
      final blockedRes = await supabaseClient
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);
      final blockedIds = (blockedRes as List)
          .map((b) => b['blocked_id'] as String)
          .toList();
      List<String> followingIds = [];
      if (followingOnly) {
        final followingRes = await supabaseClient
            .from('follows')
            .select('following_id')
            .eq('follower_id', userId);
        followingIds = (followingRes as List)
            .map((f) => f['following_id'] as String)
            .toList();
        if (followingIds.isEmpty) return [];
      }
      var query = supabaseClient
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)');
      if (followingOnly && followingIds.isNotEmpty) {
        query = query.inFilter('author_id', followingIds);
      }
      if (blockedIds.isNotEmpty) {
        query = query.not('author_id', 'in',
            '(${blockedIds.map((id) => "'$id'").join(',')})');
      }
      if (lastCreatedAt != null) {
        query = query.lt('created_at', lastCreatedAt.toIso8601String());
      } else if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .maybeSingle();
        if (lastPost != null) {
          query = query.lt('created_at', lastPost['created_at']);
        }
      }
      final response =
          await query.order('created_at', ascending: false).limit(limit);
      _logger.debug(
          'Fetched ${(response as List).length} feed posts',
          tag: 'SocialDataSource');
      final rawPosts =
          (response as List).map((json) => PostModel.fromJson(json)).toList();
      if (rawPosts.isEmpty) return [];
      final postIds = rawPosts.map((p) => p.id).toList();
      final likedRes = await supabaseClient
          .from('likes')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      final savedRes = await supabaseClient
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      final likedSet = {
        for (final r in likedRes as List) r['post_id'] as String
      };
      final savedSet = {
        for (final r in savedRes as List) r['post_id'] as String
      };
      return rawPosts
          .map((m) => m
              .copyWith(
                isLikedByCurrentUser: likedSet.contains(m.id),
                isSavedByCurrentUser: savedSet.contains(m.id),
              )
              .toEntity())
          .toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch feed posts',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('피드를 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<Post>> _getExplorePosts(int limit, String? lastPostId,
      {DateTime? lastCreatedAt}) async {
    try {
      _logger.debug('Getting explore posts', tag: 'SocialDataSource');
      var query = supabaseClient
          .from('posts')
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)');
      if (lastCreatedAt != null) {
        query = query.lt('created_at', lastCreatedAt.toIso8601String());
      } else if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .maybeSingle();
        if (lastPost != null) {
          query = query.lt('created_at', lastPost['created_at']);
        }
      }
      final response = await query
          .order('likes_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();
      _logger.debug('Found ${posts.length} explore posts',
          tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to get explore posts',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('탐색 게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<Post> _updatePost(Post post) async {
    try {
      _logger.debug('Updating post: ${post.id}', tag: 'SocialDataSource');
      final postModel = PostModel.fromEntity(post);
      final response = await supabaseClient
          .from('posts')
          .update({
            'caption': postModel.caption,
            'hashtags': postModel.hashtags,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', post.id)
          .select('*, users!posts_author_id_fkey(id, display_name, photo_url)')
          .single();
      final updatedPost = PostModel.fromJson(response).toEntity();
      _logger.debug('Successfully updated post: ${post.id}',
          tag: 'SocialDataSource');
      return updatedPost;
    } catch (e, stackTrace) {
      _logger.error('Failed to update post',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 수정 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      _logger.debug('Deleting post: $postId', tag: 'SocialDataSource');
      await supabaseClient.from('posts').delete().eq('id', postId);
      _logger.debug('Post deleted successfully: $postId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete post',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }
}
