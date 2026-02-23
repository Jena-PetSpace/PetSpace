part of 'notifications_bloc.dart';

abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsState {}

class NotificationsLoading extends NotificationsState {}

class NotificationsLoaded extends NotificationsState {
  final List<Notification> notifications;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? error;

  const NotificationsLoaded({
    required this.notifications,
    required this.hasReachedMax,
    this.isLoadingMore = false,
    this.error,
  });

  NotificationsLoaded copyWith({
    List<Notification>? notifications,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? error,
  }) {
    return NotificationsLoaded(
      notifications: notifications ?? this.notifications,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [notifications, hasReachedMax, isLoadingMore, error];
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object?> get props => [message];
}