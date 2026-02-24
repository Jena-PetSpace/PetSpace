part of 'chat_rooms_bloc.dart';

abstract class ChatRoomsState extends Equatable {
  const ChatRoomsState();

  @override
  List<Object?> get props => [];
}

class ChatRoomsInitial extends ChatRoomsState {}

class ChatRoomsLoading extends ChatRoomsState {}

class ChatRoomsLoaded extends ChatRoomsState {
  final List<ChatRoom> rooms;

  const ChatRoomsLoaded({required this.rooms});

  @override
  List<Object?> get props => [rooms];
}

class ChatRoomsError extends ChatRoomsState {
  final String message;

  const ChatRoomsError({required this.message});

  @override
  List<Object?> get props => [message];
}

class ChatRoomCreated extends ChatRoomsState {
  final ChatRoom room;

  const ChatRoomCreated({required this.room});

  @override
  List<Object?> get props => [room];
}
