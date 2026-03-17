import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/health_record.dart';
import '../repositories/health_repository.dart';

class GetUpcomingRecords implements UseCase<List<HealthRecord>, GetUpcomingRecordsParams> {
  final HealthRepository repository;

  GetUpcomingRecords(this.repository);

  @override
  Future<Either<Failure, List<HealthRecord>>> call(GetUpcomingRecordsParams params) {
    return repository.getUpcomingRecords(
      userId: params.userId,
      daysAhead: params.daysAhead,
    );
  }
}

class GetUpcomingRecordsParams extends Equatable {
  final String userId;
  final int daysAhead;

  const GetUpcomingRecordsParams({
    required this.userId,
    this.daysAhead = 30,
  });

  @override
  List<Object?> get props => [userId, daysAhead];
}
