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
    on<NotificationBadgeIncrementRequested>(_onIncrementRequested);
  }

  Future<void> _onLoadRequested(
    NotificationBadgeLoadRequested event,
    Emitter<NotificationBadgeState> emit,
  ) async {
    final result =
        await socialRepository.getUnreadNotificationsCount(event.userId);
    result.fold(
      (failure) => null,
      (count) => emit(state.copyWith(count: count)),
    );
  }

  Future<void> _onRefreshRequested(
    NotificationBadgeRefreshRequested event,
    Emitter<NotificationBadgeState> emit,
  ) async {
    final result =
        await socialRepository.getUnreadNotificationsCount(event.userId);
    result.fold(
      (failure) => null,
      (count) => emit(state.copyWith(count: count)),
    );
  }

  void _onIncrementRequested(
    NotificationBadgeIncrementRequested event,
    Emitter<NotificationBadgeState> emit,
  ) {
    emit(state.copyWith(count: state.count + 1));
  }
}
