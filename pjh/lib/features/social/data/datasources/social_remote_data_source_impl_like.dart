part of 'social_remote_data_source.dart';

extension _SocialDsLike on SocialRemoteDataSourceImpl {
  Future<void> _likePost(String postId, String userId) async {
    try {
      _logger.debug('Liking post: $postId by $userId', tag: 'SocialDataSource');
      await supabaseClient.from('likes').upsert({
        'post_id': postId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,post_id', ignoreDuplicates: true);
      await supabaseClient
          .rpc('increment_post_likes', params: {'post_id': postId});
      _logger.debug('Successfully liked post: $postId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to like post',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('좋아요 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _unlikePost(String postId, String userId) async {
    try {
      _logger.debug('Unliking post: $postId by $userId',
          tag: 'SocialDataSource');
      final deleted = await supabaseClient
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .select();
      if (deleted.isNotEmpty) {
        await supabaseClient
            .rpc('decrement_post_likes', params: {'post_id': postId});
      }
      _logger.debug('Successfully unliked post: $postId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to unlike post',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
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
      _logger.error('Failed to check like status',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
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
      final userIds = (response as List)
          .map((json) => json['user_id'] as String)
          .toList();
      _logger.debug('Found ${userIds.length} likes', tag: 'SocialDataSource');
      return userIds;
    } catch (e, stackTrace) {
      _logger.error('Failed to get post likes',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('좋아요 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }
}
