import '../../domain/entities/chat_participant.dart';

class ChatParticipantModel {
  final String id;
  final String roomId;
  final String userId;
  final String? displayName;
  final String? photoUrl;
  final String role;
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final bool isActive;

  const ChatParticipantModel({
    required this.id,
    required this.roomId,
    required this.userId,
    this.displayName,
    this.photoUrl,
    this.role = 'member',
    required this.joinedAt,
    required this.lastReadAt,
    this.isActive = true,
  });

  factory ChatParticipantModel.fromJson(Map<String, dynamic> json) {
    // JOIN된 users 데이터 처리
    final userData = json['users'] as Map<String, dynamic>?;

    return ChatParticipantModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String,
      displayName: userData?['display_name'] as String? ?? json['display_name'] as String?,
      photoUrl: userData?['photo_url'] as String? ?? json['photo_url'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joined_at'] as String),
      lastReadAt: DateTime.parse(json['last_read_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'user_id': userId,
      'role': role,
      'is_active': isActive,
    };
  }

  ChatParticipant toEntity() {
    return ChatParticipant(
      id: id,
      roomId: roomId,
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl,
      role: role == 'admin' ? ChatRole.admin : ChatRole.member,
      joinedAt: joinedAt,
      lastReadAt: lastReadAt,
      isActive: isActive,
    );
  }

  /// 유저 검색 결과를 ChatParticipantModel로 변환
  factory ChatParticipantModel.fromUserJson(Map<String, dynamic> json) {
    return ChatParticipantModel(
      id: '',
      roomId: '',
      userId: json['id'] as String,
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      role: 'member',
      joinedAt: DateTime.now(),
      lastReadAt: DateTime.now(),
      isActive: true,
    );
  }
}
