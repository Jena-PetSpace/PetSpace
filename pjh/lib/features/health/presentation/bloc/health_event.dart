part of 'health_bloc.dart';

abstract class HealthEvent extends Equatable {
  const HealthEvent();

  @override
  List<Object?> get props => [];
}

class LoadHealthRecords extends HealthEvent {
  final String petId;
  final String? userId;
  final HealthRecordType? type;

  const LoadHealthRecords({
    required this.petId,
    this.userId,
    this.type,
  });

  @override
  List<Object?> get props => [petId, userId, type];
}

class AddHealthRecordEvent extends HealthEvent {
  final HealthRecord record;
  final String operationId;

  const AddHealthRecordEvent({
    required this.record,
    required this.operationId,
  });

  @override
  List<Object?> get props => [record, operationId];
}

class UpdateHealthRecordEvent extends HealthEvent {
  final HealthRecord record;
  final String operationId;

  const UpdateHealthRecordEvent({
    required this.record,
    required this.operationId,
  });

  @override
  List<Object?> get props => [record, operationId];
}

class DeleteHealthRecordEvent extends HealthEvent {
  final String recordId;
  final String operationId;

  const DeleteHealthRecordEvent({
    required this.recordId,
    required this.operationId,
  });

  @override
  List<Object?> get props => [recordId, operationId];
}
