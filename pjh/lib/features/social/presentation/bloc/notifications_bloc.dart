import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/notification.dart';
import '../../domain/repositories/social_repository.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final SocialRepository socialRepository;

  NotificationsBloc({
    required this.socialRepository,
  }) : super(NotificationsInitial()) {
    on<LoadNotificationsRequested>(_onLoadNotificationsRequested);
    on<RefreshNotificationsRequested>(_onRefreshNotificationsRequested);
    on<LoadMoreNotificationsRequested>(_onLoadMoreNotificationsRequested);
    on<MarkNotificationAsReadRequested>(_onMarkNotificationAsReadRequested);
    on<MarkAllNotificationsAsReadRequested>(_onMarkAllNotificationsAsReadRequested);
  }

  Future<void> _onLoadNotificationsRequested(
    LoadNotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    emit(NotificationsLoading());

    final result = await socialRepository.getUserNotifications(
      userId: event.userId,
      limit: event.limit,
    );

    result.fold(
      (failure) => emit(NotificationsError(failure.message)),
      (notifications) => emit(NotificationsLoaded(
        notifications: notifications,
        hasReachedMax: notifications.length < event.limit,
      )),
    );
  }

  Future<void> _onRefreshNotificationsRequested(
    RefreshNotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final result = await socialRepository.getUserNotifications(
      userId: event.userId,
      limit: 20,
    );

    result.fold(
      (failure) => emit(NotificationsError(failure.message)),
      (notifications) => emit(NotificationsLoaded(
        notifications: notifications,
        hasReachedMax: notifications.length < 20,
      )),
    );
  }

  Future<void> _onLoadMoreNotificationsRequested(
    LoadMoreNotificationsRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is NotificationsLoaded) {
      final currentState = state as NotificationsLoaded;
      if (currentState.hasReachedMax) return;

      emit(currentState.copyWith(isLoadingMore: true));

      final result = await socialRepository.getUserNotifications(
        userId: event.userId,
        limit: 20,
        lastNotificationId: currentState.notifications.isNotEmpty
            ? currentState.notifications.last.id
            : null,
      );

      result.fold(
        (failure) => emit(currentState.copyWith(
          isLoadingMore: false,
          error: failure.message,
        )),
        (newNotifications) => emit(currentState.copyWith(
          notifications: [...currentState.notifications, ...newNotifications],
          hasReachedMax: newNotifications.length < 20,
          isLoadingMore: false,
          error: null,
        )),
      );
    }
  }

  Future<void> _onMarkNotificationAsReadRequested(
    MarkNotificationAsReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    await socialRepository.markNotificationAsRead(event.notificationId);

    // Optimistically update the notification in current state
    if (state is NotificationsLoaded) {
      final currentState = state as NotificationsLoaded;
      final updatedNotifications = currentState.notifications.map((notification) {
        if (notification.id == event.notificationId) {
          return notification.copyWith(isRead: true);
        }
        return notification;
      }).toList();

      emit(currentState.copyWith(notifications: updatedNotifications));
    }
  }

  Future<void> _onMarkAllNotificationsAsReadRequested(
    MarkAllNotificationsAsReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is NotificationsLoaded) {
      final currentState = state as NotificationsLoaded;

      // Mark all notifications as read optimistically
      final updatedNotifications = currentState.notifications.map((notification) {
        return notification.copyWith(isRead: true);
      }).toList();

      emit(currentState.copyWith(notifications: updatedNotifications));

      // Call repository to mark all notifications as read
      final result = await socialRepository.markAllNotificationsAsRead(event.userId);

      result.fold(
        (failure) {
          // Revert optimistic update on failure
          emit(currentState.copyWith(error: failure.message));
        },
        (_) {
          // Update was successful, keep the optimistic state
        },
      );
    }
  }
}