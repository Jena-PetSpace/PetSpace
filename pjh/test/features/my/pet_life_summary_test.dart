import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/my/presentation/utils/pet_life_summary.dart';

void main() {
  group('PetLifeSummary.dominantEmotionLabel', () {
    test('8감정 영문 키를 한글 라벨로 변환', () {
      expect(PetLifeSummary.dominantEmotionLabel('happiness'), '기쁨');
      expect(PetLifeSummary.dominantEmotionLabel('calm'), '편안');
      expect(PetLifeSummary.dominantEmotionLabel('excitement'), '흥분');
      expect(PetLifeSummary.dominantEmotionLabel('curiosity'), '호기심');
      expect(PetLifeSummary.dominantEmotionLabel('anxiety'), '불안');
      expect(PetLifeSummary.dominantEmotionLabel('fear'), '공포');
      expect(PetLifeSummary.dominantEmotionLabel('sadness'), '슬픔');
      expect(PetLifeSummary.dominantEmotionLabel('discomfort'), '불편');
    });

    test('미상 키는 빈 문자열', () {
      expect(PetLifeSummary.dominantEmotionLabel('unknown'), '');
    });
  });

  group('PetLifeSummary 분석 요약', () {
    test('분석이 있으면 "분석 N회 · 최근 <감정>"', () {
      const s = PetLifeSummary(
        analysisCount: 5,
        latestDominantEmotion: 'happiness',
        healthTitle: null,
        healthDate: null,
      );
      expect(s.hasAnalysis, isTrue);
      expect(s.analysisLabel, '분석 5회 · 최근 기쁨');
    });

    test('분석 0회면 hasAnalysis=false, 안내 라벨', () {
      const s = PetLifeSummary(
        analysisCount: 0,
        latestDominantEmotion: null,
        healthTitle: null,
        healthDate: null,
      );
      expect(s.hasAnalysis, isFalse);
      expect(s.analysisLabel, '아직 분석 기록이 없어요');
    });
  });

  group('PetLifeSummary 건강 요약', () {
    test('건강 기록이 있으면 "<제목> · <상대시각>"', () {
      final now = DateTime(2026, 6, 15, 12);
      final s = PetLifeSummary(
        analysisCount: 0,
        latestDominantEmotion: null,
        healthTitle: '체중 5.2kg',
        healthDate: DateTime(2026, 6, 12, 12), // 3일 전
      );
      expect(s.hasHealth, isTrue);
      expect(s.healthLabelAt(now), '체중 5.2kg · 3일 전');
    });

    test('건강 기록이 없으면 hasHealth=false', () {
      const s = PetLifeSummary(
        analysisCount: 0,
        latestDominantEmotion: null,
        healthTitle: null,
        healthDate: null,
      );
      expect(s.hasHealth, isFalse);
    });
  });
}
