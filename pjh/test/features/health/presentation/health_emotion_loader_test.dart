import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/domain/repositories/emotion_repository.dart';
import 'package:meong_nyang_diary/features/health/presentation/controllers/health_emotion_loader.dart';
import 'package:mocktail/mocktail.dart';

class _MockEmotionRepository extends Mock implements EmotionRepository {}

EmotionAnalysis _analysis() => EmotionAnalysis(
      id: 'analysis-1',
      userId: 'user-1',
      petId: 'pet-1',
      imageUrl: '',
      localImagePath: '',
      emotions: const EmotionScores(
        happiness: 1,
        sadness: 0,
        anxiety: 0,
        curiosity: 0,
      ),
      confidence: 1,
      analyzedAt: DateTime(2026, 7, 19),
      tags: const [],
    );

void main() {
  late _MockEmotionRepository repository;
  late RepositoryHealthEmotionLoader loader;

  setUp(() {
    repository = _MockEmotionRepository();
    loader = RepositoryHealthEmotionLoader(repository: repository);
  });

  test('success preserves analyses and latest uses the one-item contract',
      () async {
    final analysis = _analysis();
    when(
      () => repository.getAnalysisHistory(
        userId: 'user-1',
        petId: 'pet-1',
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => Right([analysis]));

    final result = await loader.loadHistory(
      userId: 'user-1',
      petId: 'pet-1',
    );
    final latest = await loader.loadLatest(
      userId: 'user-1',
      petId: 'pet-1',
    );

    expect(result.isFailure, false);
    expect(result.analyses, [analysis]);
    expect(latest, analysis);
  });

  test('repository failure is distinct from a successful empty result',
      () async {
    when(
      () => repository.getAnalysisHistory(
        userId: 'user-1',
        petId: 'pet-1',
        limit: 30,
      ),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'raw backend detail')),
    );
    final failure = await loader.loadHistory(
      userId: 'user-1',
      petId: 'pet-1',
    );

    when(
      () => repository.getAnalysisHistory(
        userId: 'user-1',
        petId: 'pet-1',
        limit: 30,
      ),
    ).thenAnswer((_) async => const Right([]));
    final empty = await loader.loadHistory(
      userId: 'user-1',
      petId: 'pet-1',
    );

    expect(failure.isFailure, true);
    expect(failure.analyses, isEmpty);
    expect(empty.isFailure, false);
    expect(empty.analyses, isEmpty);
  });
}
