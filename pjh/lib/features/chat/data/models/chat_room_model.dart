import '../../domain/entities/chat_room.dart';
import 'chat_participant_model.dart';

class ChatRoomModel {
  final String id;
  final String type;
  final String? name;
  final String? description;
  final String? avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final List<ChatParticipantModel> participants;
  final int unreadCount;

  const ChatRoomModel({
    required this.id,
    required this.type,
    this.name,
    this.description,
    this.avatarUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.participants = const [],
    this.unreadCount = 0,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json, {int unreadCount = 0}) {
    final participantsList = json['chat_participants'] as List<dynamic>?;
    final participants = participantsList
            ?.map((p) => ChatParticipantModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return ChatRoomModel(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String?,
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      participants: participants,
      unreadCount: unreadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'created_by': createdBy,
    };
  }

  ChatRoom toEntity() {
    return ChatRoom(
      id: id,
      type: type == 'group' ? ChatRoomType.group : ChatRoomType.direct,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastMessageSenderId: lastMessageSenderId,
      participants: participants.map((p) => p.toEntity()).toList(),
      unreadCount: unreadCount,
    );
  }
}
