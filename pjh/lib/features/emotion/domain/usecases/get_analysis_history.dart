import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/emotion_analysis.dart';
import '../repositories/emotion_repository.dart';

class GetAnalysisHistory implements UseCase<List<EmotionAnalysis>, GetAnalysisHistoryParams> {
  final EmotionRepository repository;

  GetAnalysisHistory(this.repository);

  @override
  Future<Either<Failure, List<EmotionAnalysis>>> call(
    GetAnalysisHistoryParams params,
  ) async {
    return await repository.getAnalysisHistory(
      userId: params.userId,
      petId: params.petId,
      startDate: params.startDate,
      endDate: params.endDate,
      limit: params.limit,
    );
  }
}

class GetAnalysisHistoryParams extends Equatable {
  final String userId;
  final String? petId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;

  const GetAnalysisHistoryParams({
    required this.userId,
    this.petId,
    this.startDate,
    this.endDate,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [userId, petId, startDate, endDate, limit];
}