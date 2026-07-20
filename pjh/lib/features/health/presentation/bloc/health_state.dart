part of 'health_bloc.dart';

abstract class HealthState extends Equatable {
  const HealthState();

  @override
  List<Object?> get props => [];
}

class HealthInitial extends HealthState {}

class HealthLoading extends HealthState {
  final String petId;

  const HealthLoading({required this.petId});

  @override
  List<Object?> get props => [petId];
}

enum HealthMutationType { add, update, delete }

enum HealthMutationPhase { idle, pending, succeeded, failed }

class HealthMutationState extends Equatable {
  final String operationId;
  final HealthMutationType? type;
  final HealthMutationPhase phase;
  final String? message;

  const HealthMutationState({
    this.operationId = '',
    this.type,
    this.phase = HealthMutationPhase.idle,
    this.message,
  });

  bool matches(String value) => operationId == value && operationId.isNotEmpty;

  @override
  List<Object?> get props => [operationId, type, phase, message];
}

class HealthLoaded extends HealthState {
  final String petId;
  final String? userId;
  final List<HealthRecord> records;
  final List<HealthRecord> upcomingAlerts;
  final String? error;
  final HealthMutationState mutation;

  const HealthLoaded({
    required this.petId,
    this.userId,
    required this.records,
    this.upcomingAlerts = const [],
    this.error,
    this.mutation = const HealthMutationState(),
  });

  HealthLoaded copyWith({
    String? petId,
    String? userId,
    List<HealthRecord>? records,
    List<HealthRecord>? upcomingAlerts,
    String? error,
    bool clearError = false,
    HealthMutationState? mutation,
  }) {
    return HealthLoaded(
      petId: petId ?? this.petId,
      userId: userId ?? this.userId,
      records: records ?? this.records,
      upcomingAlerts: upcomingAlerts ?? this.upcomingAlerts,
      error: clearError ? null : error ?? this.error,
      mutation: mutation ?? this.mutation,
    );
  }

  @override
  List<Object?> get props =>
      [petId, userId, records, upcomingAlerts, error, mutation];
}

class HealthError extends HealthState {
  final String message;
  final String? petId;

  const HealthError(this.message, {this.petId});

  @override
  List<Object?> get props => [message, petId];
}
