part of 'chat_badge_bloc.dart';

class ChatBadgeState extends Equatable {
  final int count;

  const ChatBadgeState({this.count = 0});

  ChatBadgeState copyWith({int? count}) {
    return ChatBadgeState(count: count ?? this.count);
  }

  @override
  List<Object?> get props => [count];
}
