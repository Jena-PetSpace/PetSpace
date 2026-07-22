import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/health_record.dart';
import '../../domain/repositories/health_repository.dart';
import '../../domain/usecases/get_health_records.dart';
import '../../domain/usecases/add_health_record.dart';
import '../../domain/usecases/update_health_record.dart';
import '../../domain/usecases/delete_health_record.dart';
import '../../domain/usecases/get_upcoming_records.dart';

part 'health_event.dart';
part 'health_state.dart';

class HealthBloc extends Bloc<HealthEvent, HealthState> {
  final HealthRepository healthRepository;
  final GetHealthRecords getHealthRecords;
  final AddHealthRecord addHealthRecord;
  final UpdateHealthRecord updateHealthRecord;
  final DeleteHealthRecord deleteHealthRecord;
  final GetUpcomingRecords getUpcomingRecords;
  int _loadGeneration = 0;

  HealthBloc({
    required this.healthRepository,
    required this.getHealthRecords,
    required this.addHealthRecord,
    required this.updateHealthRecord,
    required this.deleteHealthRecord,
    required this.getUpcomingRecords,
  }) : super(HealthInitial()) {
    on<LoadHealthRecords>(_onLoadHealthRecords);
    on<AddHealthRecordEvent>(_onAddHealthRecord);
    on<UpdateHealthRecordEvent>(_onUpdateHealthRecord);
    on<DeleteHealthRecordEvent>(_onDeleteHealthRecord);
  }

  Future<void> _onLoadHealthRecords(
    LoadHealthRecords event,
    Emitter<HealthState> emit,
  ) async {
    final generation = ++_loadGeneration;
    emit(HealthLoading(petId: event.petId));

    final result = await getHealthRecords(GetHealthRecordsParams(
      petId: event.petId,
      type: event.type,
    ));
    if (generation != _loadGeneration) return;

    await result.fold(
      (_) async => emit(HealthError(
        '건강 기록을 불러오지 못했어요. 연결을 확인한 뒤 다시 시도해주세요.',
        petId: event.petId,
      )),
      (records) async {
        List<HealthRecord> upcoming = [];
        String? upcomingError;
        if (event.userId != null) {
          final upcomingResult = await getUpcomingRecords(
            GetUpcomingRecordsParams(
              userId: event.userId!,
              petId: event.petId,
            ),
          );
          if (generation != _loadGeneration) return;
          upcomingResult.fold(
            (_) => upcomingError = '다음 케어 일정을 새로 확인하지 못했어요.',
            (list) => upcoming = list,
          );
        }
        emit(HealthLoaded(
          petId: event.petId,
          userId: event.userId,
          records: records,
          upcomingAlerts: upcoming,
          error: upcomingError,
        ));
      },
    );
  }

  Future<void> _onAddHealthRecord(
    AddHealthRecordEvent event,
    Emitter<HealthState> emit,
  ) async {
    final currentState = state;
    final loadGeneration = _loadGeneration;
    if (currentState is! HealthLoaded ||
        currentState.petId != event.record.petId ||
        currentState.mutation.phase == HealthMutationPhase.pending) {
      return;
    }
    emit(currentState.copyWith(
      clearError: true,
      mutation: HealthMutationState(
        operationId: event.operationId,
        type: HealthMutationType.add,
        phase: HealthMutationPhase.pending,
      ),
    ));

    final result =
        await addHealthRecord(AddHealthRecordParams(record: event.record));

    await result.fold(
      (_) async {
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        const message = '기록을 저장하지 못했어요. 입력 내용은 유지되니 다시 시도해주세요.';
        emit(currentState.copyWith(
          error: message,
          mutation: HealthMutationState(
            operationId: event.operationId,
            type: HealthMutationType.add,
            phase: HealthMutationPhase.failed,
            message: message,
          ),
        ));
      },
      (newRecord) async {
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        final next = currentState.copyWith(
          records: [newRecord, ...currentState.records],
          clearError: true,
        );
        final refreshed = await _withRefreshedUpcoming(
          next,
          operationId: event.operationId,
          type: HealthMutationType.add,
        );
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        emit(refreshed);
      },
    );
  }

  Future<void> _onUpdateHealthRecord(
    UpdateHealthRecordEvent event,
    Emitter<HealthState> emit,
  ) async {
    final currentState = state;
    final loadGeneration = _loadGeneration;
    if (currentState is! HealthLoaded ||
        currentState.petId != event.record.petId ||
        currentState.mutation.phase == HealthMutationPhase.pending) {
      return;
    }
    emit(currentState.copyWith(
      clearError: true,
      mutation: HealthMutationState(
        operationId: event.operationId,
        type: HealthMutationType.update,
        phase: HealthMutationPhase.pending,
      ),
    ));

    final result = await updateHealthRecord(
        UpdateHealthRecordParams(record: event.record));

    await result.fold(
      (_) async {
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        const message = '변경사항을 저장하지 못했어요. 입력 내용은 유지되니 다시 시도해주세요.';
        emit(currentState.copyWith(
          error: message,
          mutation: HealthMutationState(
            operationId: event.operationId,
            type: HealthMutationType.update,
            phase: HealthMutationPhase.failed,
            message: message,
          ),
        ));
      },
      (updatedRecord) async {
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        final updatedRecords = currentState.records
            .map((record) =>
                record.id == updatedRecord.id ? updatedRecord : record)
            .toList();
        final next = currentState.copyWith(
          records: updatedRecords,
          clearError: true,
        );
        final refreshed = await _withRefreshedUpcoming(
          next,
          operationId: event.operationId,
          type: HealthMutationType.update,
        );
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        emit(refreshed);
      },
    );
  }

  Future<void> _onDeleteHealthRecord(
    DeleteHealthRecordEvent event,
    Emitter<HealthState> emit,
  ) async {
    final currentState = state;
    final loadGeneration = _loadGeneration;
    if (currentState is! HealthLoaded ||
        currentState.mutation.phase == HealthMutationPhase.pending) {
      return;
    }
    emit(currentState.copyWith(
      clearError: true,
      mutation: HealthMutationState(
        operationId: event.operationId,
        type: HealthMutationType.delete,
        phase: HealthMutationPhase.pending,
      ),
    ));

    final result = await deleteHealthRecord(
      DeleteHealthRecordParams(recordId: event.recordId),
    );

    await result.fold(
      (_) async {
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        const message = '기록을 삭제하지 못했어요. 기존 기록은 그대로 유지됩니다.';
        emit(currentState.copyWith(
          error: message,
          mutation: HealthMutationState(
            operationId: event.operationId,
            type: HealthMutationType.delete,
            phase: HealthMutationPhase.failed,
            message: message,
          ),
        ));
      },
      (_) async {
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        final next = currentState.copyWith(
          records: currentState.records
              .where((record) => record.id != event.recordId)
              .toList(),
          clearError: true,
        );
        final refreshed = await _withRefreshedUpcoming(
          next,
          operationId: event.operationId,
          type: HealthMutationType.delete,
        );
        if (!_isCurrentScope(currentState, loadGeneration)) return;
        emit(refreshed);
      },
    );
  }

  bool _isCurrentScope(HealthLoaded started, int loadGeneration) {
    final current = state;
    return loadGeneration == _loadGeneration &&
        current is HealthLoaded &&
        current.petId == started.petId;
  }

  Future<HealthLoaded> _withRefreshedUpcoming(
    HealthLoaded next, {
    required String operationId,
    required HealthMutationType type,
  }) async {
    var upcoming = next.upcomingAlerts;
    String? refreshError;
    final userId = next.userId;
    if (userId != null) {
      final result = await getUpcomingRecords(
        GetUpcomingRecordsParams(userId: userId, petId: next.petId),
      );
      result.fold(
        (_) => refreshError = '다음 케어 일정을 새로 확인하지 못했어요.',
        (records) => upcoming = records,
      );
    }
    return next.copyWith(
      upcomingAlerts: upcoming,
      error: refreshError,
      clearError: refreshError == null,
      mutation: HealthMutationState(
        operationId: operationId,
        type: type,
        phase: HealthMutationPhase.succeeded,
      ),
    );
  }
}
