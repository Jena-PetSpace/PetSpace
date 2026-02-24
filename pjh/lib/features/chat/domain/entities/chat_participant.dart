import 'package:equatable/equatable.dart';

enum ChatRole { admin, member }

class ChatParticipant extends Equatable {
  final String id;
  final String roomId;
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final ChatRole role;
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final bool isActive;

  const ChatParticipant({
    required this.id,
    required this.roomId,
    required this.userId,
    this.displayName,
    this.photoUrl,
    this.role = ChatRole.member,
    required this.joinedAt,
    required this.lastReadAt,
    this.isActive = true,
  });

  ChatParticipant copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? displayName,
    String? photoUrl,
    ChatRole? role,
    DateTime? joinedAt,
    DateTime? lastReadAt,
    bool? isActive,
  }) {
    return ChatParticipant(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id, roomId, userId, displayName, photoUrl,
        role, joinedAt, lastReadAt, isActive,
      ];
}
