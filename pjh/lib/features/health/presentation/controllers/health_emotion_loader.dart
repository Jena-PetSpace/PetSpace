import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../emotion/domain/repositories/emotion_repository.dart';

enum HealthEmotionLoadStatus { success, failure }

class HealthEmotionHistoryResult {
  final HealthEmotionLoadStatus status;
  final List<EmotionAnalysis> analyses;

  const HealthEmotionHistoryResult._({
    required this.status,
    required this.analyses,
  });

  const HealthEmotionHistoryResult.success(List<EmotionAnalysis> analyses)
      : this._(
          status: HealthEmotionLoadStatus.success,
          analyses: analyses,
        );

  const HealthEmotionHistoryResult.failure()
      : this._(
          status: HealthEmotionLoadStatus.failure,
          analyses: const [],
        );

  bool get isFailure => status == HealthEmotionLoadStatus.failure;
}

abstract interface class HealthEmotionLoader {
  Future<HealthEmotionHistoryResult> loadHistory({
    required String userId,
    required String petId,
    int limit = 30,
  });

  Future<EmotionAnalysis?> loadLatest({
    required String userId,
    required String petId,
  });
}

class RepositoryHealthEmotionLoader implements HealthEmotionLoader {
  final EmotionRepository _repository;

  const RepositoryHealthEmotionLoader({
    required EmotionRepository repository,
  }) : _repository = repository;

  @override
  Future<HealthEmotionHistoryResult> loadHistory({
    required String userId,
    required String petId,
    int limit = 30,
  }) async {
    final result = await _repository.getAnalysisHistory(
      userId: userId,
      petId: petId,
      limit: limit,
    );
    return result.fold(
      (_) => const HealthEmotionHistoryResult.failure(),
      HealthEmotionHistoryResult.success,
    );
  }

  @override
  Future<EmotionAnalysis?> loadLatest({
    required String userId,
    required String petId,
  }) async {
    final result = await loadHistory(
      userId: userId,
      petId: petId,
      limit: 1,
    );
    if (result.isFailure || result.analyses.isEmpty) return null;
    return result.analyses.first;
  }
}
