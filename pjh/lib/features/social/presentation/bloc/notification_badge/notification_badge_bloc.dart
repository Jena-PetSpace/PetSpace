import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/repositories/social_repository.dart';

part 'notification_badge_event.dart';
part 'notification_badge_state.dart';

class NotificationBadgeBloc
    extends Bloc<NotificationBadgeEvent, NotificationBadgeState> {
  final SocialRepository socialRepository;

  NotificationBadgeBloc({required this.socialRepository})
      : super(const NotificationBadgeState()) {
    on<NotificationBadgeLoadRequested>(_onLoadRequested);
    on<NotificationBadgeRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onLoadRequested(
    NotificationBadgeLoadRequested event,
    Emitter<NotificationBadgeState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    final result = await socialRepository.getUnreadNotificationsCount(
      event.userId,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isRefreshing: false, errorMessage: failure.message),
      ),
      (count) => emit(
        state.copyWith(count: count, isRefreshing: false, clearError: true),
      ),
    );
  }

  Future<void> _onRefreshRequested(
    NotificationBadgeRefreshRequested event,
    Emitter<NotificationBadgeState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearError: true));
    final result = await socialRepository.getUnreadNotificationsCount(
      event.userId,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isRefreshing: false, errorMessage: failure.message),
      ),
      (count) => emit(
        state.copyWith(count: count, isRefreshing: false, clearError: true),
      ),
    );
  }
}
