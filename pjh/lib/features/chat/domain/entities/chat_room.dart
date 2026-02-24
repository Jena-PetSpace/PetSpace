import 'package:equatable/equatable.dart';
import 'chat_participant.dart';

enum ChatRoomType { direct, group }

class ChatRoom extends Equatable {
  final String id;
  final ChatRoomType type;
  final String? name;
  final String? description;
  final String? avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final List<ChatParticipant> participants;
  final int unreadCount;

  const ChatRoom({
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

  /// 1:1 채팅에서 상대방 참여자 반환
  ChatParticipant? getOtherParticipant(String currentUserId) {
    if (type != ChatRoomType.direct) return null;
    try {
      return participants.firstWhere((p) => p.userId != currentUserId);
    } catch (_) {
      return null;
    }
  }

  /// 표시용 이름 (1:1이면 상대방 이름, 그룹이면 그룹명)
  String displayName(String currentUserId) {
    if (type == ChatRoomType.group) return name ?? '그룹 채팅';
    final other = getOtherParticipant(currentUserId);
    return other?.displayName ?? '알 수 없는 사용자';
  }

  /// 표시용 아바타 URL
  String? displayAvatarUrl(String currentUserId) {
    if (type == ChatRoomType.group) return avatarUrl;
    final other = getOtherParticipant(currentUserId);
    return other?.photoUrl;
  }

  ChatRoom copyWith({
    String? id,
    ChatRoomType? type,
    String? name,
    String? description,
    String? avatarUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    List<ChatParticipant>? participants,
    int? unreadCount,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      participants: participants ?? this.participants,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [
        id, type, name, description, avatarUrl, createdBy,
        createdAt, updatedAt, lastMessage, lastMessageAt,
        lastMessageSenderId, participants, unreadCount,
      ];
}
