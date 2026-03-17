import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/health_repository.dart';

class DeleteHealthRecord implements UseCase<void, DeleteHealthRecordParams> {
  final HealthRepository repository;

  DeleteHealthRecord(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteHealthRecordParams params) {
    return repository.deleteHealthRecord(params.recordId);
  }
}

class DeleteHealthRecordParams extends Equatable {
  final String recordId;

  const DeleteHealthRecordParams({required this.recordId});

  @override
  List<Object?> get props => [recordId];
}
