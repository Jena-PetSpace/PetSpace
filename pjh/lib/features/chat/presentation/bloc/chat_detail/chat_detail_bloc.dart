import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/usecases/get_chat_messages.dart';
import '../../../domain/usecases/send_message.dart';
import '../../../domain/usecases/send_image_message.dart';
import '../../../domain/usecases/update_last_read.dart';

part 'chat_detail_event.dart';
part 'chat_detail_state.dart';

class ChatDetailBloc extends Bloc<ChatDetailEvent, ChatDetailState> {
  final GetChatMessages getChatMessages;
  final SendMessage sendMessage;
  final SendImageMessage sendImageMessage;
  final UpdateLastRead updateLastRead;

  ChatDetailBloc({
    required this.getChatMessages,
    required this.sendMessage,
    required this.sendImageMessage,
    required this.updateLastRead,
  }) : super(ChatDetailInitial()) {
    on<ChatDetailLoadRequested>(_onLoadRequested);
    on<ChatDetailLoadMoreRequested>(_onLoadMoreRequested);
    on<ChatDetailSendTextRequested>(_onSendTextRequested);
    on<ChatDetailSendImageRequested>(_onSendImageRequested);
    on<ChatDetailMarkAsReadRequested>(_onMarkAsReadRequested);
    on<ChatDetailNewMessageReceived>(_onNewMessageReceived);
  }

  Future<void> _onLoadRequested(
    ChatDetailLoadRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    emit(ChatDetailLoading());
    final result = await getChatMessages(GetChatMessagesParams(roomId: event.roomId));
    result.fold(
      (failure) => emit(ChatDetailError(message: failure.message)),
      (messages) => emit(ChatDetailLoaded(
        messages: messages,
        hasReachedMax: messages.length < 30,
      )),
    );
  }

  Future<void> _onLoadMoreRequested(
    ChatDetailLoadMoreRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatDetailLoaded || currentState.hasReachedMax || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    final lastMessageId = currentState.messages.isNotEmpty ? currentState.messages.last.id : null;
    final result = await getChatMessages(GetChatMessagesParams(
      roomId: event.roomId,
      lastMessageId: lastMessageId,
    ));

    result.fold(
      (failure) => emit(currentState.copyWith(isLoadingMore: false)),
      (newMessages) => emit(currentState.copyWith(
        messages: [...currentState.messages, ...newMessages],
        hasReachedMax: newMessages.length < 30,
        isLoadingMore: false,
      )),
    );
  }

  Future<void> _onSendTextRequested(
    ChatDetailSendTextRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatDetailLoaded) return;

    emit(currentState.copyWith(isSending: true));

    final result = await sendMessage(SendMessageParams(
      roomId: event.roomId,
      senderId: event.senderId,
      content: event.content,
    ));

    result.fold(
      (failure) => emit(currentState.copyWith(isSending: false)),
      (message) {
        // 중복 방지
        final exists = currentState.messages.any((m) => m.id == message.id);
        if (!exists) {
          emit(currentState.copyWith(
            messages: [message, ...currentState.messages],
            isSending: false,
          ));
        } else {
          emit(currentState.copyWith(isSending: false));
        }
      },
    );
  }

  Future<void> _onSendImageRequested(
    ChatDetailSendImageRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatDetailLoaded) return;

    emit(currentState.copyWith(isSending: true));

    final result = await sendImageMessage(SendImageMessageParams(
      roomId: event.roomId,
      senderId: event.senderId,
      imageFile: event.imageFile,
    ));

    result.fold(
      (failure) => emit(currentState.copyWith(isSending: false)),
      (message) {
        final exists = currentState.messages.any((m) => m.id == message.id);
        if (!exists) {
          emit(currentState.copyWith(
            messages: [message, ...currentState.messages],
            isSending: false,
          ));
        } else {
          emit(currentState.copyWith(isSending: false));
        }
      },
    );
  }

  Future<void> _onMarkAsReadRequested(
    ChatDetailMarkAsReadRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    await updateLastRead(UpdateLastReadParams(
      roomId: event.roomId,
      userId: event.userId,
    ));
  }

  void _onNewMessageReceived(
    ChatDetailNewMessageReceived event,
    Emitter<ChatDetailState> emit,
  ) {
    final currentState = state;
    if (currentState is! ChatDetailLoaded) return;

    // 중복 방지
    final exists = currentState.messages.any((m) => m.id == event.message.id);
    if (!exists) {
      emit(currentState.copyWith(
        messages: [event.message, ...currentState.messages],
      ));
    }
  }
}
