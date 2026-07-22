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
    on<MarkAllNotificationsAsReadRequested>(
        _onMarkAllNotificationsAsReadRequested);
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
      (_) => emit(const NotificationsError('알림을 불러오지 못했어요.')),
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
      (_) => emit(const NotificationsError('알림을 새로고침하지 못했어요.')),
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
        (_) => emit(currentState.copyWith(
          isLoadingMore: false,
          error: '알림을 더 불러오지 못했어요.',
        )),
        (newNotifications) => emit(currentState.copyWith(
          notifications: [...currentState.notifications, ...newNotifications],
          hasReachedMax: newNotifications.length < 20,
          isLoadingMore: false,
          clearError: true,
        )),
      );
    }
  }

  Future<void> _onMarkNotificationAsReadRequested(
    MarkNotificationAsReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded ||
        current.pendingReadIds.contains(event.notificationId)) {
      return;
    }
    emit(
      current.copyWith(
        pendingReadIds: {...current.pendingReadIds, event.notificationId},
        clearActionError: true,
      ),
    );
    final result =
        await socialRepository.markNotificationAsRead(event.notificationId);
    final latest = state;
    if (latest is! NotificationsLoaded) return;
    final pending = {...latest.pendingReadIds}..remove(event.notificationId);
    result.fold(
      (_) => emit(
        latest.copyWith(
          pendingReadIds: pending,
          actionError: '알림을 읽음으로 처리하지 못했어요.',
        ),
      ),
      (_) => emit(
        latest.copyWith(
          notifications: latest.notifications
              .map(
                (notification) => notification.id == event.notificationId
                    ? notification.copyWith(isRead: true)
                    : notification,
              )
              .toList(),
          pendingReadIds: pending,
          clearActionError: true,
        ),
      ),
    );
  }

  Future<void> _onMarkAllNotificationsAsReadRequested(
    MarkAllNotificationsAsReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    final current = state;
    if (current is! NotificationsLoaded || current.isMarkingAllRead) return;
    emit(
      current.copyWith(
        isMarkingAllRead: true,
        clearActionError: true,
      ),
    );
    final result =
        await socialRepository.markAllNotificationsAsRead(event.userId);
    final latest = state;
    if (latest is! NotificationsLoaded) return;
    result.fold(
      (_) => emit(
        latest.copyWith(
          isMarkingAllRead: false,
          actionError: '모든 알림을 읽음으로 처리하지 못했어요.',
        ),
      ),
      (_) => emit(
        latest.copyWith(
          notifications: latest.notifications
              .map((notification) => notification.copyWith(isRead: true))
              .toList(),
          isMarkingAllRead: false,
          allReadSuccessCount: latest.allReadSuccessCount + 1,
          clearActionError: true,
        ),
      ),
    );
  }
}
