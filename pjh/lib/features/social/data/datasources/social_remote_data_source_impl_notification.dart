part of 'social_remote_data_source.dart';

extension _SocialDsNotification on SocialRemoteDataSourceImpl {
  Future<List<Notification>> _getUserNotifications(
      String userId, int limit, String? lastNotificationId) async {
    try {
      _logger.debug('Getting user notifications: $userId',
          tag: 'SocialDataSource');
      var query = supabaseClient
          .from('notifications')
          .select('*')
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
      _logger.debug('Found ${notifications.length} notifications',
          tag: 'SocialDataSource');
      return notifications;
    } catch (e, stackTrace) {
      _logger.error('Failed to get notifications',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      _logger.debug('Marking notification as read: $notificationId',
          tag: 'SocialDataSource');
      await supabaseClient
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
      _logger.debug(
          'Successfully marked notification as read: $notificationId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to mark notification as read',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _markAllNotificationsAsRead(String userId) async {
    try {
      _logger.debug(
          'Marking all notifications as read for user: $userId',
          tag: 'SocialDataSource');
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      _logger.debug(
          'Successfully marked all notifications as read for user: $userId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to mark all notifications as read',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('모든 알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _createNotification(Notification notification) async {
    try {
      _logger.debug('Creating notification: ${notification.id}',
          tag: 'SocialDataSource');
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
      _logger.debug('Successfully created notification: ${notification.id}',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to create notification',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 생성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      _logger.debug('Deleting notification: $notificationId',
          tag: 'SocialDataSource');
      await supabaseClient
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      _logger.debug('Successfully deleted notification: $notificationId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete notification',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _reportPost(
      String postId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting post: $postId by $reporterId',
          tag: 'SocialDataSource');
      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_post_id': postId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug('Successfully reported post: $postId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report post',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _reportComment(
      String commentId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting comment: $commentId by $reporterId',
          tag: 'SocialDataSource');
      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_comment_id': commentId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug('Successfully reported comment: $commentId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report comment',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<void> _reportUser(
      String reportedUserId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting user: $reportedUserId by $reporterId',
          tag: 'SocialDataSource');
      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      _logger.debug('Successfully reported user: $reportedUserId',
          tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report user',
          error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }
}
