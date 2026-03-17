part of 'social_remote_data_source.dart';

  Future<Post> createPost(Post post, List<File> images) async {
    try {
      _logger.debug('Creating post: ${post.id}', tag: 'SocialDataSource');

      // Post 엔티티를 PostModel로 변환
      final postModel = PostModel.fromEntity(post);

      // Supabase에 게시글 생성
      final response = await supabaseClient
          .from('posts')
          .insert(postModel.toJson())
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .single();

      _logger.debug('Post created successfully: ${response['id']}', tag: 'SocialDataSource');

      // 응답을 PostModel로 변환 후 Entity로 변환
      final createdPostModel = PostModel.fromJson(response);
      return createdPostModel.toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to create post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 작성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<Post> getPost(String postId) async {
    try {
      _logger.debug('Getting post: $postId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .eq('id', postId)
          .single();

      final post = PostModel.fromJson(response).toEntity();

      _logger.debug('Successfully fetched post: $postId', tag: 'SocialDataSource');
      return post;
    } catch (e, stackTrace) {
      _logger.error('Failed to get post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Post>> getUserPosts(String userId, int limit, String? lastPostId) async {
    try {
      _logger.debug('Getting user posts: $userId', tag: 'SocialDataSource');

      var query = supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .eq('author_id', userId);

      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();

        query = query.lt('created_at', lastPost['created_at']);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      _logger.debug('Found ${posts.length} posts for user', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to get user posts', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Post>> getFeedPosts(String userId, int limit, String? lastPostId) async {
    try {
      _logger.debug('Getting feed posts for user: $userId', tag: 'SocialDataSource');

      // Supabase에서 게시글 목록 가져오기 (users 테이블 JOIN)
      final response = await supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      _logger.debug('Fetched ${response.length} feed posts', tag: 'SocialDataSource');

      // 응답을 PostModel 리스트로 변환 후 Entity 리스트로 변환
      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch feed posts', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('피드를 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Post>> getExplorePosts(int limit, String? lastPostId) async {
    try {
      _logger.debug('Getting explore posts', tag: 'SocialDataSource');

      var query = supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''');

      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();

        query = query.lt('created_at', lastPost['created_at']);
      }

      final response = await query
          .order('likes_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      _logger.debug('Found ${posts.length} explore posts', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to get explore posts', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('탐색 게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<Post> updatePost(Post post) async {
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
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .single();

      final updatedPost = PostModel.fromJson(response).toEntity();

      _logger.debug('Successfully updated post: ${post.id}', tag: 'SocialDataSource');
      return updatedPost;
    } catch (e, stackTrace) {
      _logger.error('Failed to update post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 수정 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      _logger.debug('Deleting post: $postId', tag: 'SocialDataSource');

      // Supabase에서 게시글 삭제
      await supabaseClient
          .from('posts')
          .delete()
          .eq('id', postId);

      _logger.debug('Post deleted successfully: $postId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> likePost(String postId, String userId) async {
    try {
      _logger.debug('Liking post: $postId by $userId', tag: 'SocialDataSource');

      // likes 테이블에 좋아요 추가
      await supabaseClient.from('likes').insert({
        'post_id': postId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // posts 테이블의 likes_count 증가
      await supabaseClient.rpc('increment_post_likes', params: {'post_id': postId});

      _logger.debug('Successfully liked post: $postId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to like post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('좋아요 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> unlikePost(String postId, String userId) async {
    try {
      _logger.debug('Unliking post: $postId by $userId', tag: 'SocialDataSource');

      // likes 테이블에서 좋아요 제거
      await supabaseClient
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);

      // posts 테이블의 likes_count 감소
      await supabaseClient.rpc('decrement_post_likes', params: {'post_id': postId});

      _logger.debug('Successfully unliked post: $postId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to unlike post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('좋아요 취소 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<bool> isPostLiked(String postId, String userId) async {
    try {
      _logger.debug('Checking if post liked: $postId by $userId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      _logger.error('Failed to check like status', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      return false;
    }
  }

  @override
  Future<List<String>> getPostLikes(String postId, int limit) async {
    try {
      _logger.debug('Getting post likes: $postId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('likes')
          .select('user_id')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .limit(limit);

      final userIds = (response as List)
          .map((json) => json['user_id'] as String)
          .toList();

      _logger.debug('Found ${userIds.length} likes', tag: 'SocialDataSource');
      return userIds;
    } catch (e, stackTrace) {
      _logger.error('Failed to get post likes', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('좋아요 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
