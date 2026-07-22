import 'dart:async';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../../core/error/failures.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/usecases/get_chat_messages.dart';
import '../../../domain/usecases/send_message.dart';
import '../../../domain/usecases/send_image_message.dart';
import '../../../domain/usecases/send_multi_image_message.dart';
import '../../../domain/usecases/update_last_read.dart';

part 'chat_detail_event.dart';
part 'chat_detail_state.dart';

class ChatDetailBloc extends Bloc<ChatDetailEvent, ChatDetailState> {
  final GetChatMessages getChatMessages;
  final SendMessage sendMessage;
  final SendImageMessage sendImageMessage;
  final SendMultiImageMessage sendMultiImageMessage;
  final UpdateLastRead updateLastRead;
  bool _sendInFlight = false;
  int _nextSendRequestId = 0;

  ChatDetailBloc({
    required this.getChatMessages,
    required this.sendMessage,
    required this.sendImageMessage,
    required this.sendMultiImageMessage,
    required this.updateLastRead,
  }) : super(ChatDetailInitial()) {
    on<ChatDetailLoadRequested>(_onLoadRequested);
    on<ChatDetailLoadMoreRequested>(_onLoadMoreRequested);
    on<ChatDetailSendTextRequested>(_onSendTextRequested);
    on<ChatDetailSendImageRequested>(_onSendImageRequested);
    on<ChatDetailSendMultipleImagesRequested>(
      _onSendMultipleImagesRequested,
    );
    on<ChatDetailRetryLastSendRequested>(_onRetryLastSendRequested);
    on<ChatDetailMarkAsReadRequested>(_onMarkAsReadRequested);
    on<ChatDetailNewMessageReceived>(_onNewMessageReceived);
    on<ChatDetailBlockApplied>(_onBlockApplied);
  }

  Future<void> _onLoadRequested(
    ChatDetailLoadRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    emit(ChatDetailLoading());
    final result =
        await getChatMessages(GetChatMessagesParams(roomId: event.roomId));
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
    if (currentState is! ChatDetailLoaded ||
        currentState.hasReachedMax ||
        currentState.isLoadingMore) {
      return;
    }

    emit(currentState.copyWith(
      isLoadingMore: true,
      clearLoadMoreError: true,
    ));

    final lastMessageId =
        currentState.messages.isNotEmpty ? currentState.messages.last.id : null;
    final result = await getChatMessages(GetChatMessagesParams(
      roomId: event.roomId,
      lastMessageId: lastMessageId,
    ));

    result.fold(
      (failure) {
        final latestState = state;
        if (latestState is! ChatDetailLoaded) return;
        emit(latestState.copyWith(
          isLoadingMore: false,
          loadMoreError: failure.message,
        ));
      },
      (newMessages) {
        final latestState = state;
        if (latestState is! ChatDetailLoaded) return;
        final existingIds =
            latestState.messages.map((message) => message.id).toSet();
        final uniqueMessages = newMessages
            .where((message) => existingIds.add(message.id))
            .toList(growable: false);
        emit(latestState.copyWith(
          messages: [...latestState.messages, ...uniqueMessages],
          hasReachedMax: newMessages.length < 30,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ));
      },
    );
  }

  Future<void> _onSendTextRequested(
    ChatDetailSendTextRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    await _performSend(
      emit: emit,
      kind: ChatSendKind.text,
      roomId: event.roomId,
      senderId: event.senderId,
      text: event.content,
    );
  }

  Future<void> _onSendImageRequested(
    ChatDetailSendImageRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    await _performSend(
      emit: emit,
      kind: ChatSendKind.image,
      roomId: event.roomId,
      senderId: event.senderId,
      images: [event.imageFile],
    );
  }

  Future<void> _onSendMultipleImagesRequested(
    ChatDetailSendMultipleImagesRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    await _performSend(
      emit: emit,
      kind: ChatSendKind.multiImage,
      roomId: event.roomId,
      senderId: event.senderId,
      images: event.images,
    );
  }

  Future<void> _onRetryLastSendRequested(
    ChatDetailRetryLastSendRequested event,
    Emitter<ChatDetailState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatDetailLoaded) return;
    final outcome = currentState.sendOutcome;
    if (outcome == null || outcome.status != ChatSendStatus.failure) return;

    await _performSend(
      emit: emit,
      kind: outcome.kind,
      roomId: outcome.roomId,
      senderId: outcome.senderId,
      text: outcome.text,
      images: outcome.images,
    );
  }

  Future<void> _performSend({
    required Emitter<ChatDetailState> emit,
    required ChatSendKind kind,
    required String roomId,
    required String senderId,
    String? text,
    List<File> images = const [],
  }) async {
    final currentState = state;
    if (currentState is! ChatDetailLoaded || _sendInFlight) return;
    if (kind == ChatSendKind.text && (text == null || text.trim().isEmpty)) {
      return;
    }
    if (kind != ChatSendKind.text && images.isEmpty) return;

    _sendInFlight = true;
    final pending = ChatSendOutcome(
      requestId: ++_nextSendRequestId,
      kind: kind,
      status: ChatSendStatus.sending,
      roomId: roomId,
      senderId: senderId,
      text: text,
      images: List<File>.unmodifiable(images),
    );
    emit(currentState.copyWith(sendOutcome: pending));

    try {
      late final Either<Failure, ChatMessage> result;
      if (kind == ChatSendKind.text) {
        result = await sendMessage(SendMessageParams(
          roomId: roomId,
          senderId: senderId,
          content: text!.trim(),
        ));
      } else if (kind == ChatSendKind.image) {
        result = await sendImageMessage(SendImageMessageParams(
          roomId: roomId,
          senderId: senderId,
          imageFile: images.first,
        ));
      } else {
        result = await sendMultiImageMessage(SendMultiImageMessageParams(
          roomId: roomId,
          senderId: senderId,
          images: images,
        ));
      }

      result.fold(
        (failure) {
          final latest = state is ChatDetailLoaded
              ? state as ChatDetailLoaded
              : currentState;
          emit(latest.copyWith(
            sendOutcome: pending.copyWith(
              status: ChatSendStatus.failure,
              errorMessage: failure.message,
            ),
          ));
        },
        (message) {
          final latest = state is ChatDetailLoaded
              ? state as ChatDetailLoaded
              : currentState;
          final exists = latest.messages.any((item) => item.id == message.id);
          emit(latest.copyWith(
            messages: exists ? latest.messages : [message, ...latest.messages],
            sendOutcome: pending.copyWith(status: ChatSendStatus.success),
          ));
        },
      );
    } finally {
      _sendInFlight = false;
    }
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

  /// 차단 직후 현재 방 즉시 재로드 — 차단 상대의 기존 메시지가
  /// 필터된 결과(repository getChatMessages)로 다시 그려진다.
  Future<void> _onBlockApplied(
    ChatDetailBlockApplied event,
    Emitter<ChatDetailState> emit,
  ) async {
    final result =
        await getChatMessages(GetChatMessagesParams(roomId: event.roomId));
    result.fold(
      (failure) => emit(ChatDetailError(message: failure.message)),
      (messages) => emit(ChatDetailLoaded(
        messages: messages,
        hasReachedMax: messages.length < 30,
      )),
    );
  }
}
