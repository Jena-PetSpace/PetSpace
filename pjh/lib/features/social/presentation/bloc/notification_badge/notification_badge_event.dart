part of 'notification_badge_bloc.dart';

abstract class NotificationBadgeEvent extends Equatable {
  const NotificationBadgeEvent();

  @override
  List<Object?> get props => [];
}

class NotificationBadgeLoadRequested extends NotificationBadgeEvent {
  final String userId;

  const NotificationBadgeLoadRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class NotificationBadgeRefreshRequested extends NotificationBadgeEvent {
  final String userId;

  const NotificationBadgeRefreshRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class NotificationBadgeIncrementRequested extends NotificationBadgeEvent {
  const NotificationBadgeIncrementRequested();
}
