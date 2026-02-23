import 'package:equatable/equatable.dart';

enum NotificationType {
  like,
  comment,
  follow,
  mention,
  emotionAnalysis,
  friendRequest,
  postShare,
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