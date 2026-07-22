part of 'social_remote_data_source.dart';

extension _SocialDsNotification on SocialRemoteDataSourceImpl {
  Future<List<Notification>> _getUserNotifications(
    String userId,
    int limit,
    String? lastNotificationId,
  ) async {
    try {
      _logger.debug(
        'Getting user notifications: $userId',
        tag: 'SocialDataSource',
      );
      var query = supabaseClient
          .from('notifications')
          .select(
            '*, sender:users!notifications_sender_id_fkey(display_name, photo_url)',
          )
          .eq('user_id', userId);
      if (lastNotificationId != null) {
        final lastNotification = await supabaseClient
            .from('notifications')
            .select('created_at')
            .eq('id', lastNotificationId)
            .single();
        query = query.lt('created_at', lastNotification['created_at']);
      }
      final response =
          await query.order('created_at', ascending: false).limit(limit);
      final notifications = (response as List)
          .map(
            (json) => NotificationModel.fromSupabaseJson(
              Map<String, dynamic>.from(json as Map),
            ).toEntity(),
          )
          .toList();
      _logger.debug(
        'Found ${notifications.length} notifications',
        tag: 'SocialDataSource',
      );
      return notifications;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get notifications',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('알림을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<int> _getUnreadNotificationsCount(String userId) async {
    try {
      final response = await supabaseClient
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to count unread notifications',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('안읽은 알림 개수를 불러오는 중 오류가 발생했습니다.');
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      _logger.debug(
        'Marking notification as read: $notificationId',
        tag: 'SocialDataSource',
      );
      await supabaseClient
          .from('notifications')
          .update({'read': true}).eq('id', notificationId);
      _logger.debug(
        'Successfully marked notification as read: $notificationId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to mark notification as read',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _markAllNotificationsAsRead(String userId) async {
    try {
      _logger.debug(
        'Marking all notifications as read for user: $userId',
        tag: 'SocialDataSource',
      );
      await supabaseClient
          .from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);
      _logger.debug(
        'Successfully marked all notifications as read for user: $userId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to mark all notifications as read',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('모든 알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      _logger.debug(
        'Deleting notification: $notificationId',
        tag: 'SocialDataSource',
      );
      await supabaseClient
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      _logger.debug(
        'Successfully deleted notification: $notificationId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete notification',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('알림 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _reportPost(
    String postId,
    String reporterId,
    String reason,
  ) async {
    try {
      _logger.debug(
        'Reporting post: $postId by $reporterId',
        tag: 'SocialDataSource',
      );
      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_post_id': postId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug(
        'Successfully reported post: $postId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to report post',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('게시물 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _reportComment(
    String commentId,
    String reporterId,
    String reason,
  ) async {
    try {
      _logger.debug(
        'Reporting comment: $commentId by $reporterId',
        tag: 'SocialDataSource',
      );
      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_comment_id': commentId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug(
        'Successfully reported comment: $commentId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to report comment',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('댓글 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _reportUser(
    String reportedUserId,
    String reporterId,
    String reason,
  ) async {
    try {
      _logger.debug(
        'Reporting user: $reportedUserId by $reporterId',
        tag: 'SocialDataSource',
      );
      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug(
        'Successfully reported user: $reportedUserId',
        tag: 'SocialDataSource',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to report user',
        error: e,
        stackTrace: stackTrace,
        tag: 'SocialDataSource',
      );
      throw Exception('사용자 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }
}
