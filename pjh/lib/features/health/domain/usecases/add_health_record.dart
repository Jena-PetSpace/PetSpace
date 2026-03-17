import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/health_record.dart';
import '../repositories/health_repository.dart';

class AddHealthRecord implements UseCase<HealthRecord, AddHealthRecordParams> {
  final HealthRepository repository;

  AddHealthRecord(this.repository);

  @override
  Future<Either<Failure, HealthRecord>> call(AddHealthRecordParams params) {
    return repository.addHealthRecord(params.record);
  }
}

class AddHealthRecordParams extends Equatable {
  final HealthRecord record;

  const AddHealthRecordParams({required this.record});

  @override
  List<Object?> get props => [record];
}
