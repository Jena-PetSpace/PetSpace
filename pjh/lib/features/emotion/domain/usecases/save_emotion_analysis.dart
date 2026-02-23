import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/emotion_analysis.dart';
import '../repositories/emotion_repository.dart';
import 'package:dartz/dartz.dart';

class SaveEmotionAnalysisParams {
  final EmotionAnalysis analysis;
  final String? memo;

  const SaveEmotionAnalysisParams({
    required this.analysis,
    this.memo,
  });
}

class SaveEmotionAnalysis
    extends UseCase<void, SaveEmotionAnalysisParams> {
  final EmotionRepository repository;

  SaveEmotionAnalysis(this.repository);

  @override
  Future<Either<Failure, void>> call(
    SaveEmotionAnalysisParams params,
  ) async {
    return await repository.saveAnalysis(params.analysis);
  }
}