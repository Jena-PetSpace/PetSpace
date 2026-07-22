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
  final bool isRefreshing;
  final String? refreshErrorMessage;

  const ChatRoomsLoaded({
    required this.rooms,
    this.isRefreshing = false,
    this.refreshErrorMessage,
  });

  ChatRoomsLoaded copyWith({
    List<ChatRoom>? rooms,
    bool? isRefreshing,
    String? refreshErrorMessage,
    bool clearRefreshError = false,
  }) {
    return ChatRoomsLoaded(
      rooms: rooms ?? this.rooms,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshErrorMessage: clearRefreshError
          ? null
          : refreshErrorMessage ?? this.refreshErrorMessage,
    );
  }

  @override
  List<Object?> get props => [rooms, isRefreshing, refreshErrorMessage];
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

class ChatRoomCreating extends ChatRoomsState {
  const ChatRoomCreating();
}

class ChatRoomCreateFailure extends ChatRoomsState {
  final String message;

  const ChatRoomCreateFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
