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
          .select(
            '*, users!comments_author_id_fkey(id, display_name, photo_url)',
          )
          .single();
      _logger.debug(
        'Comment created successfully: ${response['id']}',
        tag: 'SocialDataSource',
      );
      final createdComment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });
      return createdComment.toEntity();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create comment',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('댓글 작성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<Comment> _getComment(String commentId) async {
    try {
      _logger.debug('Getting comment: $commentId', tag: 'SocialDataSource');
      final response = await supabaseClient
          .from('comments')
          .select(
            '*, users!comments_author_id_fkey(id, display_name, photo_url)',
          )
          .eq('id', commentId)
          .single();
      final comment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });
      return comment.toEntity();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get comment',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('댓글을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<List<Comment>> _getPostComments(
    String postId,
    int limit,
    String? lastCommentId,
  ) async {
    try {
      _logger.debug('Getting post comments: $postId', tag: 'SocialDataSource');
      var queryBuilder = supabaseClient
          .from('comments')
          .select(
            '*, users!comments_author_id_fkey(id, display_name, photo_url)',
          )
          .eq('post_id', postId)
          .isFilter('parent_id', null);
      if (lastCommentId != null) {
        final lastComment = await supabaseClient
            .from('comments')
            .select('id, created_at')
            .eq('post_id', postId)
            .isFilter('parent_id', null)
            .eq('id', lastCommentId)
            .maybeSingle();
        if (lastComment == null) return [];
        queryBuilder = queryBuilder.or(
          _commentCursorFilter(Map<String, dynamic>.from(lastComment)),
        );
      }
      final response = await queryBuilder
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);
      _logger.debug(
        'Fetched ${response.length} comments',
        tag: 'SocialDataSource',
      );
      final parentRows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (parentRows.isEmpty) return [];

      final parentIds = parentRows.map((row) => row['id'] as String).toList();
      final repliesResponse = await supabaseClient
          .from('comments')
          .select(
            '*, users!comments_author_id_fkey(id, display_name, photo_url)',
          )
          .inFilter('parent_id', parentIds)
          .order('created_at', ascending: true)
          .order('id', ascending: true);
      final replyRows = (repliesResponse as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final allIds = <String>{
        ...parentIds,
        ...replyRows.map((row) => row['id'] as String),
      };
      final likedIds = <String>{};
      final currentUserId = supabaseClient.auth.currentUser?.id;
      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          allIds.isNotEmpty) {
        final likesResponse = await supabaseClient
            .from('comment_likes')
            .select('comment_id')
            .eq('user_id', currentUserId)
            .inFilter('comment_id', allIds.toList());
        likedIds.addAll(
          (likesResponse as List).map(
            (row) => (row as Map)['comment_id'] as String,
          ),
        );
      }

      final repliesByParent = <String, List<Comment>>{};
      for (final row in replyRows) {
        final reply = _commentFromJoinedRow(row, likedIds);
        final parentId = reply.parentId;
        if (parentId != null) {
          (repliesByParent[parentId] ??= <Comment>[]).add(reply);
        }
      }

      return parentRows.map((row) {
        final parent = _commentFromJoinedRow(row, likedIds);
        return parent.copyWith(
          replies: repliesByParent[parent.id] ?? const <Comment>[],
        );
      }).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch comments',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('댓글을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Comment _commentFromJoinedRow(
    Map<String, dynamic> row,
    Set<String> likedIds,
  ) {
    final user = row['users'] as Map<String, dynamic>?;
    return CommentModel.fromJson({
      ...row,
      'author_name': user?['display_name'] ?? '',
      'author_profile_image': user?['photo_url'],
      'is_liked_by_current_user': likedIds.contains(row['id']),
      'replies': const <dynamic>[],
    }).toEntity();
  }

  String _commentCursorFilter(Map<String, dynamic> cursor) {
    final createdAt = _quoteCommentFilterValue(
      cursor['created_at']?.toString() ?? '',
    );
    final id = _quoteCommentFilterValue(cursor['id']?.toString() ?? '');
    return 'created_at.lt.$createdAt,and(created_at.eq.$createdAt,id.lt.$id)';
  }

  String _quoteCommentFilterValue(String value) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
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
          .select(
            '*, users!comments_author_id_fkey(id, display_name, photo_url)',
          )
          .single();
      final updatedComment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });
      return updatedComment.toEntity();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update comment',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('댓글 수정 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      _logger.debug('Deleting comment: $commentId', tag: 'SocialDataSource');
      await supabaseClient.from('comments').delete().eq('id', commentId);
      _logger.debug(
        'Comment deleted successfully: $commentId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete comment',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('댓글 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _likeComment(String commentId, String userId) async {
    try {
      _logger.debug(
        'Liking comment: $commentId by $userId',
        tag: 'SocialDataSource',
      );
      await supabaseClient.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug(
        'Successfully liked comment: $commentId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to like comment',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      if (!e.toString().contains('duplicate')) {
        throw Exception('댓글 좋아요 중 오류가 발생했습니다: ${e.toString()}');
      }
    }
  }

  Future<void> _unlikeComment(String commentId, String userId) async {
    try {
      _logger.debug(
        'Unliking comment: $commentId by $userId',
        tag: 'SocialDataSource',
      );
      await supabaseClient
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
      _logger.debug(
        'Successfully unliked comment: $commentId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to unlike comment',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('댓글 좋아요 취소 중 오류가 발생했습니다: ${e.toString()}');
    }
  }
}
