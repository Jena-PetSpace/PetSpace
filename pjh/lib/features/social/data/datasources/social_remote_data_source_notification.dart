part of 'social_remote_data_source.dart';

  Future<List<Notification>> getUserNotifications(String userId, int limit, String? lastNotificationId) async {
    try {
      _logger.debug('Getting user notifications: $userId', tag: 'SocialDataSource');

      var query = supabaseClient
          .from('notifications')
          .select('*')
          .eq('user_id', userId);

      if (lastNotificationId != null) {
        // 페이지네이션 구현
        final lastNotification = await supabaseClient
            .from('notifications')
            .select('created_at')
            .eq('id', lastNotificationId)
            .single();

        query = query.lt('created_at', lastNotification['created_at']);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final notifications = (response as List).map((json) {
        return NotificationModel(
          id: json['id'] ?? '',
          userId: json['user_id'] ?? '',
          senderId: json['sender_id'] ?? '',
          senderName: json['sender_name'] ?? '',
          senderProfileImage: json['sender_profile_image'],
          type: NotificationType.values.firstWhere(
            (e) => e.toString() == 'NotificationType.${json['type']}',
            orElse: () => NotificationType.like,
          ),
          title: json['title'] ?? '',
          body: json['body'] ?? '',
          isRead: json['is_read'] ?? false,
          createdAt: json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
          postId: json['post_id'],
          commentId: json['comment_id'],
          data: Map<String, dynamic>.from(json['data'] ?? {}),
        ).toEntity();
      }).toList();

      _logger.debug('Found ${notifications.length} notifications', tag: 'SocialDataSource');
      return notifications;
    } catch (e, stackTrace) {
      _logger.error('Failed to get notifications', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      _logger.debug('Marking notification as read: $notificationId', tag: 'SocialDataSource');

      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      _logger.debug('Successfully marked notification as read: $notificationId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to mark notification as read', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      _logger.debug('Marking all notifications as read for user: $userId', tag: 'SocialDataSource');

      // Bulk update - 모든 안 읽은 알림을 한 번의 쿼리로 업데이트
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      _logger.debug('Successfully marked all notifications as read for user: $userId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to mark all notifications as read', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('모든 알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> createNotification(Notification notification) async {
    try {
      _logger.debug('Creating notification: ${notification.id}', tag: 'SocialDataSource');

      final notificationModel = NotificationModel.fromEntity(notification);

      await supabaseClient.from('notifications').insert({
        'id': notificationModel.id,
        'user_id': notificationModel.userId,
        'sender_id': notificationModel.senderId,
        'sender_name': notificationModel.senderName,
        'sender_profile_image': notificationModel.senderProfileImage,
        'type': notificationModel.type.toString().split('.').last,
        'title': notificationModel.title,
        'body': notificationModel.body,
        'is_read': notificationModel.isRead,
        'created_at': notificationModel.createdAt.toIso8601String(),
        'post_id': notificationModel.postId,
        'comment_id': notificationModel.commentId,
        'data': notificationModel.data,
      });

      _logger.debug('Successfully created notification: ${notification.id}', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to create notification', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 생성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      _logger.debug('Deleting notification: $notificationId', tag: 'SocialDataSource');

      await supabaseClient
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      _logger.debug('Successfully deleted notification: $notificationId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete notification', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> reportPost(String postId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting post: $postId by $reporterId', tag: 'SocialDataSource');

      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_post_id': postId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully reported post: $postId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> reportComment(String commentId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting comment: $commentId by $reporterId', tag: 'SocialDataSource');

      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_comment_id': commentId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully reported comment: $commentId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report comment', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> reportUser(String reportedUserId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting user: $reportedUserId by $reporterId', tag: 'SocialDataSource');

      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully reported user: $reportedUserId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  // Search operations
  @override
  Future<List<Post>> searchPosts({
    required String query,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      _logger.debug('Searching posts with query: $query, limit: $limit', tag: 'SocialDataSource');

      var baseQuery = supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .or('caption.ilike.%$query%,hashtags.cs.{$query}');

      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();
        baseQuery = baseQuery.filter('created_at', 'lt', lastPost['created_at']);
      }

      final response = await baseQuery
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      _logger.debug('Found ${posts.length} posts', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to search posts', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 검색 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Post>> searchPostsByHashtag({
    required String hashtag,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      _logger.debug('Searching posts by hashtag: $hashtag, limit: $limit', tag: 'SocialDataSource');

      var baseQuery = supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .contains('hashtags', [hashtag]);

      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();
        baseQuery = baseQuery.filter('created_at', 'lt', lastPost['created_at']);
      }

      final response = await baseQuery
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      _logger.debug('Found ${posts.length} posts with hashtag: $hashtag', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to search posts by hashtag', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('해시태그 검색 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getPopularHashtags({
    int limit = 20,
  }) async {
    try {
      _logger.debug('Fetching popular hashtags, limit: $limit', tag: 'SocialDataSource');

      // PostgreSQL: unnest로 배열을 행으로 펼치고, 빈도수 계산
      final response = await supabaseClient.rpc('get_popular_hashtags', params: {
        'limit_count': limit,
      });

      if (response == null) {
        // RPC가 없으면 클라이언트 측에서 계산
        final posts = await supabaseClient
            .from('posts')
            .select('hashtags')
            .order('created_at', ascending: false)
            .limit(1000);

        final Map<String, int> hashtagCounts = {};
        for (final post in posts as List) {
          final hashtags = post['hashtags'] as List?;
          if (hashtags != null) {
            for (final tag in hashtags) {
              final tagStr = tag.toString();
              hashtagCounts[tagStr] = (hashtagCounts[tagStr] ?? 0) + 1;
            }
          }
        }

        final sortedTags = hashtagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return sortedTags.take(limit).map((e) => e.key).toList();
      }

      final hashtags = (response as List)
          .map((item) => item['hashtag'].toString())
          .toList();

      _logger.debug('Found ${hashtags.length} popular hashtags', tag: 'SocialDataSource');
      return hashtags;
    } catch (e, stackTrace) {
      _logger.error('Failed to get popular hashtags', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');

      // 실패 시 빈 배열 반환
      return [];
    }
  }

  @override
  Future<List<String>> getTrendingHashtags({
    int limit = 10,
    int days = 7,
  }) async {
    try {
      _logger.debug('Fetching trending hashtags, limit: $limit, days: $days', tag: 'SocialDataSource');

      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      // PostgreSQL RPC 사용 (없으면 클라이언트 측 계산)
      try {
        final response = await supabaseClient.rpc('get_trending_hashtags', params: {
          'limit_count': limit,
          'days_ago': days,
        });

        if (response != null) {
          final hashtags = (response as List)
              .map((item) => item['hashtag'].toString())
              .toList();

          _logger.debug('Found ${hashtags.length} trending hashtags', tag: 'SocialDataSource');
          return hashtags;
        }
      } catch (rpcError) {
        _logger.debug('RPC not available, using client-side calculation', tag: 'SocialDataSource');
      }

      // 폴백: 클라이언트 측 계산
      final posts = await supabaseClient
          .from('posts')
          .select('hashtags')
          .gte('created_at', cutoffDate.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1000);

      final Map<String, int> hashtagCounts = {};
      for (final post in posts as List) {
        final hashtags = post['hashtags'] as List?;
        if (hashtags != null) {
          for (final tag in hashtags) {
            final tagStr = tag.toString();
            hashtagCounts[tagStr] = (hashtagCounts[tagStr] ?? 0) + 1;
          }
        }
      }

      final sortedTags = hashtagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTags.take(limit).map((e) => e.key).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get trending hashtags', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');

      // 실패 시 빈 배열 반환
      return [];
    }
  }
}