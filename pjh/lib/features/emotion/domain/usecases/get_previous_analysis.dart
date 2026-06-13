import '../entities/emotion_analysis.dart';
import '../repositories/emotion_repository.dart';

/// 방금 만든 결과(current)의 "직전 분석 1건"을 조회한다.
/// 선택 기준: current.analyzedAt 보다 이전 시각인 것 중 최신
///   (+ 보조로 current.id 동일 항목 제외 — 방금 결과가 이미 저장된 경우 대비).
/// push 시점엔 current가 DB 저장 전일 수 있어 id 제외만으론 부족, analyzedAt 기준이 정답.
/// getAnalysesByPet은 created_at DESC 정렬이라 첫 매칭이 곧 최신.
/// 비교 UI(delta)는 부가 기능 — 실패·빈 결과·petId 없음은 모두 null, throw 금지.
class GetPreviousAnalysis {
  final EmotionRepository repository;

  GetPreviousAnalysis(this.repository);

  Future<EmotionAnalysis?> call({required EmotionAnalysis current}) async {
    final petId = current.petId;
    if (petId == null || petId.isEmpty) return null;

    final result = await repository.getAnalysesByPet(petId: petId, limit: 5);
    return result.fold(
      (_) => null,
      (list) {
        for (final a in list) {
          if (a.id == current.id) continue;
          if (a.analyzedAt.isBefore(current.analyzedAt)) return a;
        }
        return null;
      },
    );
  }
}
