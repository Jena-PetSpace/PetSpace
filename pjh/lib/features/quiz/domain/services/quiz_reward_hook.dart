import 'dart:developer' as dev;

/// 세트 완료 시 호출되는 보상 연계 훅.
///
/// **1차(현재)는 미적립 — no-op(로깅만).** 정식 보상(user_points/badges)은
/// 리워드스토어 구현 시점에 여기를 채운다. 운세가 게이미피케이션을 2차로 미룬 것과
/// 동일한 자리 마련 방식.
///
/// 결과 화면은 커밋(커서 전진·done·스트릭) 직후 이 훅을 1회 호출한다. 멱등 커밋이
/// 재적립을 막으므로(이미 done 이면 커밋 자체가 멱등), 훅도 완주 1회당 1번만 불린다.
abstract class QuizRewardHook {
  /// [correctCount]/[total] 정답 수, [streak] 갱신된 연속 일수.
  ///
  /// TODO(리워드스토어): 리워드스토어 구현 시 여기서 포인트·뱃지 적립 로직을 연결.
  ///   - 예: 정답 1개당 포인트, 스트릭 마일스톤(7/30일) 뱃지 등.
  ///   - 적립은 서버/DB 연동이 생긴 뒤. 그 전까지는 no-op 유지(과적립 방지).
  Future<void> onQuizCompleted({
    required int correctCount,
    required int total,
    required int streak,
  });
}

/// 1차 no-op 구현(로깅만). 보상 미적립.
class QuizRewardHookNoop implements QuizRewardHook {
  const QuizRewardHookNoop();

  @override
  Future<void> onQuizCompleted({
    required int correctCount,
    required int total,
    required int streak,
  }) async {
    // 1차: 적립 없음. 디버그 로깅만(연동 전 동작 확인용).
    dev.log(
      'onQuizCompleted(correct=$correctCount/$total, streak=$streak) — no-op(보상 미적립)',
      name: 'Quiz',
    );
  }
}
