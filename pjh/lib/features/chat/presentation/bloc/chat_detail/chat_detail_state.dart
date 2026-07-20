part of 'chat_detail_bloc.dart';

enum ChatSendKind { text, image, multiImage }

enum ChatSendStatus { sending, success, failure }

class ChatSendOutcome extends Equatable {
  final int requestId;
  final ChatSendKind kind;
  final ChatSendStatus status;
  final String roomId;
  final String senderId;
  final String? text;
  final List<File> images;
  final String? errorMessage;

  const ChatSendOutcome({
    required this.requestId,
    required this.kind,
    required this.status,
    required this.roomId,
    required this.senderId,
    this.text,
    this.images = const [],
    this.errorMessage,
  });

  ChatSendOutcome copyWith({
    ChatSendStatus? status,
    String? errorMessage,
  }) {
    return ChatSendOutcome(
      requestId: requestId,
      kind: kind,
      status: status ?? this.status,
      roomId: roomId,
      senderId: senderId,
      text: text,
      images: images,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        requestId,
        kind,
        status,
        roomId,
        senderId,
        text,
        images.map((file) => file.path).toList(growable: false),
        errorMessage,
      ];
}

abstract class ChatDetailState extends Equatable {
  const ChatDetailState();

  @override
  List<Object?> get props => [];
}

class ChatDetailInitial extends ChatDetailState {}

class ChatDetailLoading extends ChatDetailState {}

class ChatDetailLoaded extends ChatDetailState {
  final List<ChatMessage> messages;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? loadMoreError;
  final ChatSendOutcome? sendOutcome;

  const ChatDetailLoaded({
    required this.messages,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.sendOutcome,
  });

  bool get isSending => sendOutcome?.status == ChatSendStatus.sending;

  ChatDetailLoaded copyWith({
    List<ChatMessage>? messages,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
    ChatSendOutcome? sendOutcome,
    bool clearSendOutcome = false,
  }) {
    return ChatDetailLoaded(
      messages: messages ?? this.messages,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError:
          clearLoadMoreError ? null : loadMoreError ?? this.loadMoreError,
      sendOutcome: clearSendOutcome ? null : sendOutcome ?? this.sendOutcome,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        hasReachedMax,
        isLoadingMore,
        loadMoreError,
        sendOutcome,
      ];
}

class ChatDetailError extends ChatDetailState {
  final String message;

  const ChatDetailError({required this.message});

  @override
  List<Object?> get props => [message];
}
