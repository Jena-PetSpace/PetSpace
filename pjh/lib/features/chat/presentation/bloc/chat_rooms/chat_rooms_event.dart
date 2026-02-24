part of 'chat_rooms_bloc.dart';

abstract class ChatRoomsEvent extends Equatable {
  const ChatRoomsEvent();

  @override
  List<Object?> get props => [];
}

class ChatRoomsLoadRequested extends ChatRoomsEvent {
  final String userId;

  const ChatRoomsLoadRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class ChatRoomsRefreshRequested extends ChatRoomsEvent {
  final String userId;

  const ChatRoomsRefreshRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class ChatRoomsCreateDirectRequested extends ChatRoomsEvent {
  final String currentUserId;
  final String otherUserId;

  const ChatRoomsCreateDirectRequested({
    required this.currentUserId,
    required this.otherUserId,
  });

  @override
  List<Object?> get props => [currentUserId, otherUserId];
}

class ChatRoomsCreateGroupRequested extends ChatRoomsEvent {
  final String name;
  final String creatorId;
  final List<String> memberIds;

  const ChatRoomsCreateGroupRequested({
    required this.name,
    required this.creatorId,
    required this.memberIds,
  });

  @override
  List<Object?> get props => [name, creatorId, memberIds];
}
