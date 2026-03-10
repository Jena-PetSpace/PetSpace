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

  const AddHealthRecordEvent({required this.record});

  @override
  List<Object?> get props => [record];
}

class UpdateHealthRecordEvent extends HealthEvent {
  final HealthRecord record;

  const UpdateHealthRecordEvent({required this.record});

  @override
  List<Object?> get props => [record];
}

class DeleteHealthRecordEvent extends HealthEvent {
  final String recordId;

  const DeleteHealthRecordEvent({required this.recordId});

  @override
  List<Object?> get props => [recordId];
}
