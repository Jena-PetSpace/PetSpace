part of 'chat_detail_bloc.dart';

abstract class ChatDetailEvent extends Equatable {
  const ChatDetailEvent();

  @override
  List<Object?> get props => [];
}

class ChatDetailLoadRequested extends ChatDetailEvent {
  final String roomId;

  const ChatDetailLoadRequested({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

class ChatDetailLoadMoreRequested extends ChatDetailEvent {
  final String roomId;

  const ChatDetailLoadMoreRequested({required this.roomId});

  @override
  List<Object?> get props => [roomId];
}

class ChatDetailSendTextRequested extends ChatDetailEvent {
  final String roomId;
  final String senderId;
  final String content;

  const ChatDetailSendTextRequested({
    required this.roomId,
    required this.senderId,
    required this.content,
  });

  @override
  List<Object?> get props => [roomId, senderId, content];
}

class ChatDetailSendImageRequested extends ChatDetailEvent {
  final String roomId;
  final String senderId;
  final File imageFile;

  const ChatDetailSendImageRequested({
    required this.roomId,
    required this.senderId,
    required this.imageFile,
  });

  @override
  List<Object?> get props => [roomId, senderId, imageFile];
}

class ChatDetailMarkAsReadRequested extends ChatDetailEvent {
  final String roomId;
  final String userId;

  const ChatDetailMarkAsReadRequested({
    required this.roomId,
    required this.userId,
  });

  @override
  List<Object?> get props => [roomId, userId];
}

class ChatDetailNewMessageReceived extends ChatDetailEvent {
  final ChatMessage message;

  const ChatDetailNewMessageReceived({required this.message});

  @override
  List<Object?> get props => [message];
}
