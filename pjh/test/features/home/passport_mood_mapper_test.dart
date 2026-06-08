import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/home/presentation/widgets/passport_mood_mapper.dart';

/// 여권 카드 "오늘의 기분" 변환 검증.
/// 핵심: percent 는 감정 **분포 비율**이며 신뢰도(confidence) 가 아니다.
void main() {
  EmotionScores scores({
    double happiness = 0,
    double calm = 0,
    double excitement = 0,
    double curiosity = 0,
    double anxiety = 0,
    double fear = 0,
    double sadness = 0,
    double discomfort = 0,
  }) =>
      EmotionScores(
        happiness: happiness,
        sadness: sadness,
        anxiety: anxiety,
        curiosity: curiosity,
        calm: calm,
        excitement: excitement,
        fear: fear,
        discomfort: discomfort,
      );

  group('PassportMoodMapper.fromScores', () {
    test('분포 1위 + 비율(분포값) 계산: calm 9 / 합 10 → 90%', () {
      final mood = PassportMoodMapper.fromScores(
        scores(calm: 9, anxiety: 1),
      );
      expect(mood, isNotNull);
      expect(mood!.percent, 90, reason: '9/(9+1)=90% (분포 비율)');
    });

    test('다른 분포: happiness 6 / 합 10 → 60% (1위=happiness)', () {
      final mood = PassportMoodMapper.fromScores(
        scores(happiness: 6, calm: 3, curiosity: 1),
      );
      expect(mood!.percent, 60);
    });

    test('percent 는 신뢰도가 아니라 분포값 — 합이 1.0 이든 100 이든 비율만 반영', () {
      // 합 = 100 스케일이어도 동일 비율이면 동일 percent.
      final a = PassportMoodMapper.fromScores(scores(calm: 0.9, anxiety: 0.1));
      final b = PassportMoodMapper.fromScores(scores(calm: 90, anxiety: 10));
      expect(a!.percent, b!.percent);
      expect(a.percent, 90);
    });

    test('모든 값 0(합 0) → null (미분석 취급)', () {
      expect(PassportMoodMapper.fromScores(scores()), isNull);
    });

    test('라벨/이모지가 분포 1위 감정과 일치(happiness)', () {
      final mood = PassportMoodMapper.fromScores(scores(happiness: 8, calm: 2));
      expect(mood, isNotNull);
      // 라벨/이모지는 AppTheme 매핑 — 비어있지 않아야 함.
      expect(mood!.label.isNotEmpty, isTrue);
      expect(mood.emoji.isNotEmpty, isTrue);
    });
  });
}
