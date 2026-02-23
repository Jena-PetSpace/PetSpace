import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/emotion_analysis.dart';
import '../repositories/emotion_repository.dart';

class AnalyzeEmotion implements UseCase<EmotionAnalysis, AnalyzeEmotionParams> {
  final EmotionRepository repository;

  AnalyzeEmotion(this.repository);

  @override
  Future<Either<Failure, EmotionAnalysis>> call(
    AnalyzeEmotionParams params,
  ) async {
    return await repository.analyzeEmotion(
      imagePath: params.imagePath,
      petId: params.petId,
    );
  }
}

class AnalyzeEmotionParams extends Equatable {
  final String imagePath;
  final String? petId;

  const AnalyzeEmotionParams({
    required this.imagePath,
    this.petId,
  });

  @override
  List<Object?> get props => [imagePath, petId];
}