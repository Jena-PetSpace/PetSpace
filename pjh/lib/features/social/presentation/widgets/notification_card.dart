import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/notification.dart' as social_notification;

class NotificationCard extends StatelessWidget {
  final social_notification.Notification notification;
  final VoidCallback onTap;
  final VoidCallback onMarkAsRead;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : Colors.blue.withValues(alpha: 0.05),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotificationIcon(),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationContent(),
                  SizedBox(height: 4.h),
                  Text(
                    _formatDateTime(notification.createdAt),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              SizedBox(width: 8.w),
              Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 20.r,
          backgroundImage: notification.senderProfileImage != null
              ? CachedNetworkImageProvider(notification.senderProfileImage!)
              : null,
          child: notification.senderProfileImage == null
              ? Text(
                  notification.senderName.isNotEmpty ? notification.senderName[0] : '?',
                  style: TextStyle(fontSize: 14.sp),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(2.w),
            child: Icon(
              _getNotificationTypeIcon(notification.type),
              size: 12.w,
              color: _getNotificationTypeColor(notification.type),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: notification.senderName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
              TextSpan(
                text: ' ${_getNotificationAction(notification.type)}',
                style: TextStyle(
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
        if (notification.body.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            notification.body,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.secondaryTextColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  IconData _getNotificationTypeIcon(social_notification.NotificationType type) {
    switch (type) {
      case social_notification.NotificationType.like:
        return Icons.favorite;
      case social_notification.NotificationType.comment:
        return Icons.comment;
      case social_notification.NotificationType.follow:
        return Icons.person_add;
      case social_notification.NotificationType.mention:
        return Icons.alternate_email;
      case social_notification.NotificationType.emotionAnalysis:
        return Icons.psychology;
      case social_notification.NotificationType.friendRequest:
        return Icons.person_add_alt_1;
      case social_notification.NotificationType.postShare:
        return Icons.share;
    }
  }

  Color _getNotificationTypeColor(social_notification.NotificationType type) {
    switch (type) {
      case social_notification.NotificationType.like:
        return Colors.red;
      case social_notification.NotificationType.comment:
        return Colors.blue;
      case social_notification.NotificationType.follow:
        return Colors.green;
      case social_notification.NotificationType.mention:
        return Colors.orange;
      case social_notification.NotificationType.emotionAnalysis:
        return Colors.purple;
      case social_notification.NotificationType.friendRequest:
        return Colors.teal;
      case social_notification.NotificationType.postShare:
        return Colors.indigo;
    }
  }

  String _getNotificationAction(social_notification.NotificationType type) {
    switch (type) {
      case social_notification.NotificationType.like:
        return '님이 게시물에 좋아요를 눌렀습니다';
      case social_notification.NotificationType.comment:
        return '님이 댓글을 남겼습니다';
      case social_notification.NotificationType.follow:
        return '님이 팔로우하기 시작했습니다';
      case social_notification.NotificationType.mention:
        return '님이 언급했습니다';
      case social_notification.NotificationType.emotionAnalysis:
        return '님이 감정 분석을 공유했습니다';
      case social_notification.NotificationType.friendRequest:
        return '님이 친구 요청을 보냈습니다';
      case social_notification.NotificationType.postShare:
        return '님이 게시물을 공유했습니다';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}