import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/health_record.dart';
import '../repositories/health_repository.dart';

class GetHealthRecords
    implements UseCase<List<HealthRecord>, GetHealthRecordsParams> {
  final HealthRepository repository;

  GetHealthRecords(this.repository);

  @override
  Future<Either<Failure, List<HealthRecord>>> call(
      GetHealthRecordsParams params) {
    return repository.getHealthRecords(
      petId: params.petId,
      type: params.type,
      limit: params.limit,
    );
  }
}

class GetHealthRecordsParams extends Equatable {
  final String petId;
  final HealthRecordType? type;
  final int limit;

  const GetHealthRecordsParams({
    required this.petId,
    this.type,
    this.limit = 50,
  });

  @override
  List<Object?> get props => [petId, type, limit];
}
