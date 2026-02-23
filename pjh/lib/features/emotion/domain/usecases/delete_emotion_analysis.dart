import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/emotion_repository.dart';
import 'package:dartz/dartz.dart';

class DeleteEmotionAnalysisParams {
  final String analysisId;

  const DeleteEmotionAnalysisParams({
    required this.analysisId,
  });
}

class DeleteEmotionAnalysis extends UseCase<void, DeleteEmotionAnalysisParams> {
  final EmotionRepository repository;

  DeleteEmotionAnalysis(this.repository);

  @override
  Future<Either<Failure, void>> call(
    DeleteEmotionAnalysisParams params,
  ) async {
    return await repository.deleteAnalysis(params.analysisId);
  }
}