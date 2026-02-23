import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/emotion_repository.dart';
import 'package:dartz/dartz.dart';

class GetEmotionStatisticsParams {
  final String userId;
  final String? petId;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetEmotionStatisticsParams({
    required this.userId,
    this.petId,
    this.startDate,
    this.endDate,
  });
}

class GetEmotionStatistics
    extends UseCase<Map<String, dynamic>, GetEmotionStatisticsParams> {
  final EmotionRepository repository;

  GetEmotionStatistics(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(
    GetEmotionStatisticsParams params,
  ) async {
    return await repository.getEmotionStatistics(
      userId: params.userId,
      petId: params.petId,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}