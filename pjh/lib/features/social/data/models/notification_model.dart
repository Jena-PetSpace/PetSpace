// Firebase 의존성 제거 - Supabase로 전환

import '../../domain/entities/notification.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String senderId;
  final String senderName;
  final String? senderProfileImage;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? postId;
  final String? commentId;
  final Map<String, dynamic> data;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.senderName,
    this.senderProfileImage,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
    this.postId,
    this.commentId,
    this.data = const {},
  });

  factory NotificationModel.fromSupabaseJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : const <String, dynamic>{};
    final rawSender = json['sender'];
    final sender = rawSender is Map
        ? Map<String, dynamic>.from(rawSender)
        : const <String, dynamic>{};

    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      senderId: json['sender_id'] ?? data['sender_id'] ?? '',
      senderName: sender['display_name'] ?? data['sender_name'] ?? 'PetSpace',
      senderProfileImage: sender['photo_url'],
      type: NotificationTypeContract.fromWireName(json['type'] as String?),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isRead: json['read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      postId: json['post_id'],
      commentId: json['comment_id'],
      data: data,
    );
  }

  Notification toEntity() {
    return Notification(
      id: id,
      userId: userId,
      senderId: senderId,
      senderName: senderName,
      senderProfileImage: senderProfileImage,
      type: type,
      title: title,
      body: body,
      isRead: isRead,
      createdAt: createdAt,
      postId: postId,
      commentId: commentId,
      data: data,
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? senderId,
    String? senderName,
    String? senderProfileImage,
    NotificationType? type,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    String? postId,
    String? commentId,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderProfileImage: senderProfileImage ?? this.senderProfileImage,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      data: data ?? this.data,
    );
  }
}
