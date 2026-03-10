part of 'health_bloc.dart';

abstract class HealthState extends Equatable {
  const HealthState();

  @override
  List<Object?> get props => [];
}

class HealthInitial extends HealthState {}

class HealthLoading extends HealthState {}

class HealthLoaded extends HealthState {
  final List<HealthRecord> records;
  final List<HealthRecord> upcomingAlerts;
  final String? error;

  const HealthLoaded({
    required this.records,
    this.upcomingAlerts = const [],
    this.error,
  });

  HealthLoaded copyWith({
    List<HealthRecord>? records,
    List<HealthRecord>? upcomingAlerts,
    String? error,
  }) {
    return HealthLoaded(
      records: records ?? this.records,
      upcomingAlerts: upcomingAlerts ?? this.upcomingAlerts,
      error: error,
    );
  }

  @override
  List<Object?> get props => [records, upcomingAlerts, error];
}

class HealthError extends HealthState {
  final String message;

  const HealthError(this.message);

  @override
  List<Object?> get props => [message];
}
