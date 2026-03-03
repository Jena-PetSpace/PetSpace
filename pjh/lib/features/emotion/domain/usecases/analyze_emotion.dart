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
      imagePaths: params.imagePaths,
      petId: params.petId,
    );
  }
}

class AnalyzeEmotionParams extends Equatable {
  final List<String> imagePaths;
  final String? petId;

  const AnalyzeEmotionParams({
    required this.imagePaths,
    this.petId,
  });

  @override
  List<Object?> get props => [imagePaths, petId];
}