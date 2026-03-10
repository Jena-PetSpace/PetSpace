import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/health_record.dart';

abstract class HealthRepository {
  Future<Either<Failure, List<HealthRecord>>> getHealthRecords({
    required String petId,
    HealthRecordType? type,
    int limit = 50,
  });

  Future<Either<Failure, HealthRecord>> addHealthRecord(HealthRecord record);

  Future<Either<Failure, HealthRecord>> updateHealthRecord(HealthRecord record);

  Future<Either<Failure, void>> deleteHealthRecord(String recordId);

  Future<Either<Failure, List<HealthRecord>>> getUpcomingRecords({
    required String userId,
    int daysAhead = 30,
  });
}
