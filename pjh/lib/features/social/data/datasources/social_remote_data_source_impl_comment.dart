part of 'social_remote_data_source.dart';

extension _SocialDsComment on SocialRemoteDataSourceImpl {
  Future<Comment> _createComment(Comment comment) async {
    try {
      _logger.debug('Creating comment: ${comment.id}', tag: 'SocialDataSource');
      final commentModel = CommentModel.fromEntity(comment);
      final insertData = <String, dynamic>{
        'id': commentModel.id,
        'post_id': commentModel.postId,
        'author_id': commentModel.authorId,
        'content': commentModel.content,
        'created_at': commentModel.createdAt.toIso8601String(),
      };
      if (commentModel.parentId != null) {
        insertData['parent_id'] = commentModel.parentId;
      }
      final response = await supabaseClient
          .from('comments')
          .insert(insertData)
          .select('*, users!comments_author_id_fkey(id, display_name, photo_url)')
          .single();
      _logger.debug('Comment created successfully: ${response['id']}',
          tag: 'SocialDataSource');
      final createdComment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });
      return createdComment.toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to create comment',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 작성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<Comment> _getComment(String commentId) async {
    try {
      _logger.debug('Getting comment: $commentId', tag: 'SocialDataSource');
      final response = await supabaseClient
          .from('comments')
          .select('*, users!comments_author_id_fkey(id, display_name, photo_url)')
          .eq('id', commentId)
          .single();
      final comment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });
      return comment.toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to get comment',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<Comment>> _getPostComments(
      String postId, int limit, String? lastCommentId) async {
    try {
      _logger.debug('Getting post comments: $postId', tag: 'SocialDataSource');
      var queryBuilder = supabaseClient
          .from('comments')
          .select('*, users!comments_author_id_fkey(id, display_name, photo_url)')
          .eq('post_id', postId)
          .isFilter('parent_id', null);
      if (lastCommentId != null) {
        final lastComment = await supabaseClient
            .from('comments')
            .select('created_at')
            .eq('id', lastCommentId)
            .single();
        queryBuilder =
            queryBuilder.lt('created_at', lastComment['created_at']);
      }
      final response = await queryBuilder
          .order('created_at', ascending: false)
          .limit(limit);
      _logger.debug('Fetched ${response.length} comments',
          tag: 'SocialDataSource');
      final comments =
          await Future.wait((response as List).map((json) async {
        final cId = json['id'] as String;
        final repliesRes = await supabaseClient
            .from('comments')
            .select(
                '*, users!comments_author_id_fkey(id, display_name, photo_url)')
            .eq('parent_id', cId)
            .order('created_at', ascending: true);
        final replies = (repliesRes as List)
            .map((r) => CommentModel.fromJson({
                  ...r,
                  'author_name': r['users']['display_name'],
                  'author_profile_image': r['users']['photo_url'],
                }).toEntity())
            .toList();
        return CommentModel.fromJson({
          ...json,
          'author_name': json['users']['display_name'],
          'author_profile_image': json['users']['photo_url'],
          'replies': const [],
        }).toEntity().copyWith(replies: replies);
      }));
      return comments;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch comments',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<Comment> _updateComment(Comment comment) async {
    try {
      _logger.debug('Updating comment: ${comment.id}', tag: 'SocialDataSource');
      final response = await supabaseClient
          .from('comments')
          .update({
            'content': comment.content,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', comment.id)
          .select('*, users!comments_author_id_fkey(id, display_name, photo_url)')
          .single();
      final updatedComment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });
      return updatedComment.toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to update comment',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 수정 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      _logger.debug('Deleting comment: $commentId', tag: 'SocialDataSource');
      await supabaseClient.from('comments').delete().eq('id', commentId);
      _logger.debug('Comment deleted successfully: $commentId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete comment',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _likeComment(String commentId, String userId) async {
    try {
      _logger.debug('Liking comment: $commentId by $userId',
          tag: 'SocialDataSource');
      await supabaseClient.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug('Successfully liked comment: $commentId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to like comment',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      if (!e.toString().contains('duplicate')) {
        throw Exception('댓글 좋아요 중 오류가 발생했습니다: ${e.toString()}');
      }
    }
  }

  Future<void> _unlikeComment(String commentId, String userId) async {
    try {
      _logger.debug('Unliking comment: $commentId by $userId',
          tag: 'SocialDataSource');
      await supabaseClient
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
      _logger.debug('Successfully unliked comment: $commentId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to unlike comment',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 좋아요 취소 중 오류가 발생했습니다: ${e.toString()}');
    }
  }
}
