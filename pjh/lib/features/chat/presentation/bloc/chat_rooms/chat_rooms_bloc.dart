import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/chat_room.dart';
import '../../../domain/usecases/get_chat_rooms.dart';
import '../../../domain/usecases/create_chat_room.dart';

part 'chat_rooms_event.dart';
part 'chat_rooms_state.dart';

class ChatRoomsBloc extends Bloc<ChatRoomsEvent, ChatRoomsState> {
  final GetChatRooms getChatRooms;
  final CreateDirectChat createDirectChat;
  final CreateGroupChat createGroupChat;

  ChatRoomsBloc({
    required this.getChatRooms,
    required this.createDirectChat,
    required this.createGroupChat,
  }) : super(ChatRoomsInitial()) {
    on<ChatRoomsLoadRequested>(_onLoadRequested);
    on<ChatRoomsRefreshRequested>(_onRefreshRequested);
    on<ChatRoomsCreateDirectRequested>(_onCreateDirectRequested);
    on<ChatRoomsCreateGroupRequested>(_onCreateGroupRequested);
  }

  Future<void> _onLoadRequested(
    ChatRoomsLoadRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    emit(ChatRoomsLoading());
    final result = await getChatRooms(GetChatRoomsParams(userId: event.userId));
    result.fold(
      (failure) => emit(ChatRoomsError(message: failure.message)),
      (rooms) => emit(ChatRoomsLoaded(rooms: rooms)),
    );
  }

  Future<void> _onRefreshRequested(
    ChatRoomsRefreshRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    final result = await getChatRooms(GetChatRoomsParams(userId: event.userId));
    result.fold(
      (failure) => emit(ChatRoomsError(message: failure.message)),
      (rooms) => emit(ChatRoomsLoaded(rooms: rooms)),
    );
  }

  Future<void> _onCreateDirectRequested(
    ChatRoomsCreateDirectRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    final result = await createDirectChat(CreateDirectChatParams(
      currentUserId: event.currentUserId,
      otherUserId: event.otherUserId,
    ));
    result.fold(
      (failure) => emit(ChatRoomsError(message: failure.message)),
      (room) => emit(ChatRoomCreated(room: room)),
    );
  }

  Future<void> _onCreateGroupRequested(
    ChatRoomsCreateGroupRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    final result = await createGroupChat(CreateGroupChatParams(
      name: event.name,
      creatorId: event.creatorId,
      memberIds: event.memberIds,
    ));
    result.fold(
      (failure) => emit(ChatRoomsError(message: failure.message)),
      (room) => emit(ChatRoomCreated(room: room)),
    );
  }
}
