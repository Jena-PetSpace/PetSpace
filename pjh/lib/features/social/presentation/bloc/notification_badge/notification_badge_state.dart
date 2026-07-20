part of 'notification_badge_bloc.dart';

class NotificationBadgeState extends Equatable {
  final int count;
  final bool isRefreshing;
  final String? errorMessage;

  const NotificationBadgeState({
    this.count = 0,
    this.isRefreshing = false,
    this.errorMessage,
  });

  NotificationBadgeState copyWith({
    int? count,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationBadgeState(
      count: count ?? this.count,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [count, isRefreshing, errorMessage];
}
