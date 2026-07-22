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
  final Set<String> pendingReadIds;
  final bool isMarkingAllRead;
  final int allReadSuccessCount;
  final String? actionError;

  const NotificationsLoaded({
    required this.notifications,
    required this.hasReachedMax,
    this.isLoadingMore = false,
    this.error,
    this.pendingReadIds = const <String>{},
    this.isMarkingAllRead = false,
    this.allReadSuccessCount = 0,
    this.actionError,
  });

  NotificationsLoaded copyWith({
    List<Notification>? notifications,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    Set<String>? pendingReadIds,
    bool? isMarkingAllRead,
    int? allReadSuccessCount,
    String? actionError,
    bool clearActionError = false,
  }) {
    return NotificationsLoaded(
      notifications: notifications ?? this.notifications,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      pendingReadIds: Set<String>.unmodifiable(
        pendingReadIds ?? this.pendingReadIds,
      ),
      isMarkingAllRead: isMarkingAllRead ?? this.isMarkingAllRead,
      allReadSuccessCount: allReadSuccessCount ?? this.allReadSuccessCount,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [
        notifications,
        hasReachedMax,
        isLoadingMore,
        error,
        pendingReadIds,
        isMarkingAllRead,
        allReadSuccessCount,
        actionError,
      ];
}

class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object?> get props => [message];
}
