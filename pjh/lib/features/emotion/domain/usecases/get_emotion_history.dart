import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/emotion_analysis.dart';
import '../repositories/emotion_repository.dart';
import 'package:dartz/dartz.dart';

class GetEmotionHistoryParams {
  final String userId;
  final String? petId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;

  const GetEmotionHistoryParams({
    required this.userId,
    this.petId,
    this.startDate,
    this.endDate,
    this.limit = 20,
  });
}

class GetEmotionHistory
    extends UseCase<List<EmotionAnalysis>, GetEmotionHistoryParams> {
  final EmotionRepository repository;

  GetEmotionHistory(this.repository);

  @override
  Future<Either<Failure, List<EmotionAnalysis>>> call(
    GetEmotionHistoryParams params,
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