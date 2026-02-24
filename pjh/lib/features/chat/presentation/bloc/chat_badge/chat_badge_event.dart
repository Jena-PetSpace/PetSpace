part of 'chat_badge_bloc.dart';

abstract class ChatBadgeEvent extends Equatable {
  const ChatBadgeEvent();

  @override
  List<Object?> get props => [];
}

class ChatBadgeLoadRequested extends ChatBadgeEvent {
  final String userId;

  const ChatBadgeLoadRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class ChatBadgeRefreshRequested extends ChatBadgeEvent {
  final String userId;

  const ChatBadgeRefreshRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class ChatBadgeIncrementRequested extends ChatBadgeEvent {
  const ChatBadgeIncrementRequested();
}
