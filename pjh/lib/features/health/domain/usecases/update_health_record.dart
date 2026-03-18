import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/health_record.dart';
import '../repositories/health_repository.dart';

class UpdateHealthRecord
    implements UseCase<HealthRecord, UpdateHealthRecordParams> {
  final HealthRepository repository;

  UpdateHealthRecord(this.repository);

  @override
  Future<Either<Failure, HealthRecord>> call(UpdateHealthRecordParams params) {
    return repository.updateHealthRecord(params.record);
  }
}

class UpdateHealthRecordParams extends Equatable {
  final HealthRecord record;

  const UpdateHealthRecordParams({required this.record});

  @override
  List<Object?> get props => [record];
}
