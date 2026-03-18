part of 'notification_badge_bloc.dart';

class NotificationBadgeState extends Equatable {
  final int count;

  const NotificationBadgeState({this.count = 0});

  NotificationBadgeState copyWith({int? count}) {
    return NotificationBadgeState(count: count ?? this.count);
  }

  @override
  List<Object?> get props => [count];
}
