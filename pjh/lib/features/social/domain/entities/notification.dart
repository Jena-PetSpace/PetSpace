import 'package:equatable/equatable.dart';

enum NotificationType {
  like,
  comment,
  follow,
  mention,
  system,
  adminNewPost,
  emotionAnalysis,
  healthAlert,
  friendRequest,
  postShare,
  unknown,
}

extension NotificationTypeContract on NotificationType {
  static NotificationType fromWireName(String? value) {
    switch (value) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'mention':
        return NotificationType.mention;
      case 'system':
        return NotificationType.system;
      case 'admin_new_post':
        return NotificationType.adminNewPost;
      case 'emotion_analysis':
        return NotificationType.emotionAnalysis;
      case 'health_alert':
        return NotificationType.healthAlert;
      case 'friend_request':
        return NotificationType.friendRequest;
      case 'post_share':
        return NotificationType.postShare;
      default:
        return NotificationType.unknown;
    }
  }

  String get wireName {
    switch (this) {
      case NotificationType.like:
        return 'like';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.mention:
        return 'mention';
      case NotificationType.system:
        return 'system';
      case NotificationType.adminNewPost:
        return 'admin_new_post';
      case NotificationType.emotionAnalysis:
        return 'emotion_analysis';
      case NotificationType.healthAlert:
        return 'health_alert';
      case NotificationType.friendRequest:
        return 'friend_request';
      case NotificationType.postShare:
        return 'post_share';
      case NotificationType.unknown:
        return 'unknown';
    }
  }
}

class Notification extends Equatable {
  final String id;
  final String userId;
  final String senderId;
  final String senderName;
  final String? senderProfileImage;
  final NotificationType type;
  final String title;
  final String body;
  final String? postId;
  final String? commentId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const Notification({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.senderName,
    this.senderProfileImage,
    required this.type,
    required this.title,
    required this.body,
    this.postId,
    this.commentId,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  Notification copyWith({
    String? id,
    String? userId,
    String? senderId,
    String? senderName,
    String? senderProfileImage,
    NotificationType? type,
    String? title,
    String? body,
    String? postId,
    String? commentId,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfileImage: senderProfileImage ?? this.senderProfileImage,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        senderId,
        senderName,
        senderProfileImage,
        type,
        title,
        body,
        postId,
        commentId,
        data,
        isRead,
        createdAt,
      ];
}
