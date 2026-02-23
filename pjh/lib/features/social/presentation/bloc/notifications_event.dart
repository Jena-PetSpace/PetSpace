part of 'notifications_bloc.dart';

abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotificationsRequested extends NotificationsEvent {
  final String userId;
  final int limit;

  const LoadNotificationsRequested({
    required this.userId,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [userId, limit];
}

class RefreshNotificationsRequested extends NotificationsEvent {
  final String userId;

  const RefreshNotificationsRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class LoadMoreNotificationsRequested extends NotificationsEvent {
  final String userId;

  const LoadMoreNotificationsRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class MarkNotificationAsReadRequested extends NotificationsEvent {
  final String notificationId;

  const MarkNotificationAsReadRequested({required this.notificationId});

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllNotificationsAsReadRequested extends NotificationsEvent {
  final String userId;

  const MarkAllNotificationsAsReadRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}