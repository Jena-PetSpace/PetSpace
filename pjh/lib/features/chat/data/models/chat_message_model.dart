import '../../domain/entities/chat_message.dart';

class ChatMessageModel {
  final String id;
  final String roomId;
  final String senderId;
  final String? senderName;
  final String? senderPhotoUrl;
  final String? content;
  final String type;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isDeleted;

  const ChatMessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.senderName,
    this.senderPhotoUrl,
    this.content,
    this.type = 'text',
    this.imageUrl,
    required this.createdAt,
    this.isDeleted = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    // JOIN된 users 데이터 처리
    final userData = json['users'] as Map<String, dynamic>?;

    return ChatMessageModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: userData?['display_name'] as String?,
      senderPhotoUrl: userData?['photo_url'] as String?,
      content: json['content'] as String?,
      type: json['type'] as String? ?? 'text',
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
      'type': type,
      'image_url': imageUrl,
    };
  }

  ChatMessage toEntity() {
    ChatMessageType msgType;
    switch (type) {
      case 'image':
        msgType = ChatMessageType.image;
        break;
      case 'system':
        msgType = ChatMessageType.system;
        break;
      default:
        msgType = ChatMessageType.text;
    }

    return ChatMessage(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      content: content,
      type: msgType,
      imageUrl: imageUrl,
      createdAt: createdAt,
      isDeleted: isDeleted,
    );
  }
}
