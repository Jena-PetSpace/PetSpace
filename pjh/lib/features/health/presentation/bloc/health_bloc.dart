import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/health_record.dart';
import '../../domain/repositories/health_repository.dart';

part 'health_event.dart';
part 'health_state.dart';

class HealthBloc extends Bloc<HealthEvent, HealthState> {
  final HealthRepository healthRepository;

  HealthBloc({required this.healthRepository}) : super(HealthInitial()) {
    on<LoadHealthRecords>(_onLoadHealthRecords);
    on<AddHealthRecordEvent>(_onAddHealthRecord);
    on<UpdateHealthRecordEvent>(_onUpdateHealthRecord);
    on<DeleteHealthRecordEvent>(_onDeleteHealthRecord);
  }

  Future<void> _onLoadHealthRecords(
    LoadHealthRecords event,
    Emitter<HealthState> emit,
  ) async {
    emit(HealthLoading());

    final result = await healthRepository.getHealthRecords(
      petId: event.petId,
      type: event.type,
    );

    await result.fold(
      (failure) async {
        emit(HealthError(failure.message));
      },
      (records) async {
        // 예정된 알림도 함께 로드
        List<HealthRecord> upcoming = [];
        if (event.userId != null) {
          final upcomingResult = await healthRepository.getUpcomingRecords(
            userId: event.userId!,
          );
          upcomingResult.fold(
            (_) {},
            (upcomingRecords) => upcoming = upcomingRecords,
          );
        }

        emit(HealthLoaded(records: records, upcomingAlerts: upcoming));
      },
    );
  }

  Future<void> _onAddHealthRecord(
    AddHealthRecordEvent event,
    Emitter<HealthState> emit,
  ) async {
    final currentState = state;

    final result = await healthRepository.addHealthRecord(event.record);

    result.fold(
      (failure) {
        if (currentState is HealthLoaded) {
          emit(currentState.copyWith(error: failure.message));
        } else {
          emit(HealthError(failure.message));
        }
      },
      (newRecord) {
        if (currentState is HealthLoaded) {
          final updatedRecords = [newRecord, ...currentState.records];
          emit(currentState.copyWith(records: updatedRecords, error: null));
        }
      },
    );
  }

  Future<void> _onUpdateHealthRecord(
    UpdateHealthRecordEvent event,
    Emitter<HealthState> emit,
  ) async {
    final currentState = state;

    final result = await healthRepository.updateHealthRecord(event.record);

    result.fold(
      (failure) {
        if (currentState is HealthLoaded) {
          emit(currentState.copyWith(error: failure.message));
        }
      },
      (updatedRecord) {
        if (currentState is HealthLoaded) {
          final updatedRecords = currentState.records
              .map((r) => r.id == updatedRecord.id ? updatedRecord : r)
              .toList();
          emit(currentState.copyWith(records: updatedRecords, error: null));
        }
      },
    );
  }

  Future<void> _onDeleteHealthRecord(
    DeleteHealthRecordEvent event,
    Emitter<HealthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! HealthLoaded) return;

    // 낙관적 삭제
    final updatedRecords =
        currentState.records.where((r) => r.id != event.recordId).toList();
    emit(currentState.copyWith(records: updatedRecords));

    final result = await healthRepository.deleteHealthRecord(event.recordId);

    result.fold(
      (failure) {
        // 실패 시 복원
        emit(currentState.copyWith(error: failure.message));
      },
      (_) {},
    );
  }
}
