part of 'chat_detail_bloc.dart';

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
  final bool isSending;

  const ChatDetailLoaded({
    required this.messages,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.isSending = false,
  });

  ChatDetailLoaded copyWith({
    List<ChatMessage>? messages,
    bool? hasReachedMax,
    bool? isLoadingMore,
    bool? isSending,
  }) {
    return ChatDetailLoaded(
      messages: messages ?? this.messages,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
    );
  }

  @override
  List<Object?> get props => [messages, hasReachedMax, isLoadingMore, isSending];
}

class ChatDetailError extends ChatDetailState {
  final String message;

  const ChatDetailError({required this.message});

  @override
  List<Object?> get props => [message];
}
