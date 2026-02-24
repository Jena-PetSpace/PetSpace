import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../../domain/usecases/get_unread_count.dart';

part 'chat_badge_event.dart';
part 'chat_badge_state.dart';

class ChatBadgeBloc extends Bloc<ChatBadgeEvent, ChatBadgeState> {
  final GetUnreadCount getUnreadCount;

  ChatBadgeBloc({required this.getUnreadCount}) : super(const ChatBadgeState()) {
    on<ChatBadgeLoadRequested>(_onLoadRequested);
    on<ChatBadgeRefreshRequested>(_onRefreshRequested);
    on<ChatBadgeIncrementRequested>(_onIncrementRequested);
  }

  Future<void> _onLoadRequested(
    ChatBadgeLoadRequested event,
    Emitter<ChatBadgeState> emit,
  ) async {
    final result = await getUnreadCount(IdParams(id: event.userId));
    result.fold(
      (failure) => null,
      (count) => emit(state.copyWith(count: count)),
    );
  }

  Future<void> _onRefreshRequested(
    ChatBadgeRefreshRequested event,
    Emitter<ChatBadgeState> emit,
  ) async {
    final result = await getUnreadCount(IdParams(id: event.userId));
    result.fold(
      (failure) => null,
      (count) => emit(state.copyWith(count: count)),
    );
  }

  void _onIncrementRequested(
    ChatBadgeIncrementRequested event,
    Emitter<ChatBadgeState> emit,
  ) {
    emit(state.copyWith(count: state.count + 1));
  }
}
