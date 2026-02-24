import 'package:equatable/equatable.dart';

enum ChatMessageType { text, image, system }

class ChatMessage extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final String? content;
  final ChatMessageType type;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isDeleted;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    this.content,
    this.type = ChatMessageType.text,
    this.imageUrl,
    required this.createdAt,
    this.isDeleted = false,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? content,
    ChatMessageType? type,
    String? imageUrl,
    DateTime? createdAt,
    bool? isDeleted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      content: content ?? this.content,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  List<Object?> get props => [
        id, roomId, senderId, senderName, senderPhotoUrl,
        content, type, imageUrl, createdAt, isDeleted,
      ];
}
