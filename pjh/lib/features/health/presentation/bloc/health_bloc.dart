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
    emit(HealthLoading());

    final result = await getHealthRecords(GetHealthRecordsParams(
      petId: event.petId,
      type: event.type,
    ));

    await result.fold(
      (failure) async => emit(HealthError(failure.message)),
      (records) async {
        List<HealthRecord> upcoming = [];
        if (event.userId != null) {
          final upcomingResult = await getUpcomingRecords(
            GetUpcomingRecordsParams(userId: event.userId!),
          );
          upcomingResult.fold((_) {}, (list) => upcoming = list);
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
    final result =
        await addHealthRecord(AddHealthRecordParams(record: event.record));

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
          emit(currentState.copyWith(
            records: [newRecord, ...currentState.records],
            error: null,
          ));
        }
      },
    );
  }

  Future<void> _onUpdateHealthRecord(
    UpdateHealthRecordEvent event,
    Emitter<HealthState> emit,
  ) async {
    final currentState = state;
    final result = await updateHealthRecord(
        UpdateHealthRecordParams(record: event.record));

    result.fold(
      (failure) {
        if (currentState is HealthLoaded) {
          emit(currentState.copyWith(error: failure.message));
        } else {
          emit(HealthError(failure.message));
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

    // 낙관적 삭제 → 실패 시 원복
    final optimistic =
        currentState.records.where((r) => r.id != event.recordId).toList();
    emit(currentState.copyWith(records: optimistic));

    final result = await deleteHealthRecord(
      DeleteHealthRecordParams(recordId: event.recordId),
    );

    result.fold(
      (failure) => emit(currentState.copyWith(error: failure.message)),
      (_) {},
    );
  }
}
