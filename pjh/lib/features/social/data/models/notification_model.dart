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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderProfileImage: json['senderProfileImage'],
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${json['type']}',
        orElse: () => NotificationType.like,
      ),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      postId: json['postId'],
      commentId: json['commentId'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfileImage': senderProfileImage,
      'type': type.toString().split('.').last,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'postId': postId,
      'commentId': commentId,
      'data': data,
    };
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

  factory NotificationModel.fromEntity(Notification notification) {
    return NotificationModel(
      id: notification.id,
      userId: notification.userId,
      senderId: notification.senderId,
      senderName: notification.senderName,
      senderProfileImage: notification.senderProfileImage,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      isRead: notification.isRead,
      createdAt: notification.createdAt,
      postId: notification.postId,
      commentId: notification.commentId,
      data: notification.data,
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