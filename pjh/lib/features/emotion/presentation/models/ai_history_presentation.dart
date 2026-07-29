import 'package:flutter/material.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/ai_history.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/entities/health_analysis.dart';

class AiHistoryPresentation {
  const AiHistoryPresentation._();

  static const safetyCopy =
      'AI 분석은 우리 아이를 이해하는 참고 자료예요. 걱정되는 부분이 있다면 꼭 수의사와 상담해 주세요.';

  static String emotionLabel(String key) => switch (key) {
        'happiness' => '기쁨',
        'calm' => '편안함',
        'excitement' => '신남',
        'curiosity' => '호기심',
        'anxiety' => '불안',
        'fear' => '두려움',
        'sadness' => '슬픔',
        'discomfort' => '불편함',
        _ => '분석값 확인 어려움',
      };

  static String emotionTitle(EmotionAnalysis analysis) {
    final key = dominantEmotion(analysis.emotions);
    return switch (key) {
      'happiness' => '기쁜 신호가 관찰됐어요',
      'calm' => '편안한 신호가 관찰됐어요',
      'excitement' => '신난 신호가 관찰됐어요',
      'curiosity' => '호기심 신호가 관찰됐어요',
      'anxiety' => '불안한 신호가 관찰됐어요',
      'fear' => '두려운 신호가 관찰됐어요',
      'sadness' => '슬픈 신호가 관찰됐어요',
      'discomfort' => '불편한 신호가 관찰됐어요',
      _ => '분석 신호를 다시 확인해 주세요',
    };
  }

  static String healthTitle(HealthAnalysis analysis) {
    final area = healthAreaLabel(analysis);
    return switch (healthState(analysis)) {
      HealthObservationState.stable => '$area에 특이 신호가 보이지 않아요',
      HealthObservationState.watch => '$area을 조금 더 지켜봐 주세요',
      HealthObservationState.needsAttention => '$area에 확인이 필요한 신호가 있어요',
      HealthObservationState.unknown => '$area 분석 결과를 다시 확인해 주세요',
    };
  }

  static String healthAreaLabel(HealthAnalysis analysis) {
    if (!analysis.hasKnownArea) return '기타 부위';
    return analysis.area.displayName
        .replaceAll('(전체)', '')
        .replaceAll('(BCS)', '')
        .trim();
  }

  static HealthObservationState healthState(HealthAnalysis analysis) =>
      analysis.observationState;

  static String healthStateLabel(HealthAnalysis analysis) =>
      switch (healthState(analysis)) {
        HealthObservationState.stable => '특이 신호 없음',
        HealthObservationState.watch => '지켜보기',
        HealthObservationState.needsAttention => '확인 필요',
        HealthObservationState.unknown => '분석값 확인 어려움',
      };

  static IconData healthStateIcon(HealthAnalysis analysis) =>
      switch (healthState(analysis)) {
        HealthObservationState.stable => Icons.check_circle_outline,
        HealthObservationState.watch => Icons.schedule_outlined,
        HealthObservationState.needsAttention => Icons.priority_high_rounded,
        HealthObservationState.unknown => Icons.help_outline_rounded,
      };

  static Color healthStateColor(HealthAnalysis analysis) =>
      switch (healthState(analysis)) {
        HealthObservationState.stable => AppTheme.primaryTextColor,
        HealthObservationState.watch => const Color(0xFF79520E),
        HealthObservationState.needsAttention => const Color(0xFF6F4708),
        HealthObservationState.unknown => AppTheme.secondaryTextColor,
      };

  static String dominantEmotion(EmotionScores scores) {
    final entries = _normalizedEntries(scores);
    if (entries.every((entry) => entry.value == 0)) return 'unknown';
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  static bool hasMixedSignals(EmotionScores scores) {
    final entries = _normalizedEntries(scores);
    if (entries.every((entry) => entry.value == 0)) return false;
    entries.sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    if (total <= 0 || entries.length < 2) return false;
    return ((entries[0].value - entries[1].value) / total).abs() < 0.05;
  }

  static List<AiHistoryDaySignal> buildDailySignals(
    List<EmotionAnalysis> analyses,
  ) {
    final byDay = <DateTime, List<List<double>>>{};
    for (final analysis in analyses) {
      final values = _normalizedEntries(
        analysis.emotions,
      ).map((entry) => entry.value).toList(growable: false);
      final total = values.fold<double>(0, (sum, value) => sum + value);
      if (total <= 0) continue;
      final local = analysis.analyzedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      byDay
          .putIfAbsent(day, () => [])
          .add(values.map((value) => value / total).toList(growable: false));
    }

    const keys = [
      'happiness',
      'calm',
      'excitement',
      'curiosity',
      'anxiety',
      'fear',
      'sadness',
      'discomfort',
    ];
    final result = <AiHistoryDaySignal>[];
    for (final entry in byDay.entries) {
      final averages = List<double>.filled(keys.length, 0);
      for (final row in entry.value) {
        for (var index = 0; index < keys.length; index++) {
          averages[index] += row[index];
        }
      }
      for (var index = 0; index < averages.length; index++) {
        averages[index] /= entry.value.length;
      }
      final ranked = List<int>.generate(keys.length, (index) => index)
        ..sort((a, b) => averages[b].compareTo(averages[a]));
      result.add(
        AiHistoryDaySignal(
          day: entry.key,
          dominantEmotion: keys[ranked.first],
          hasMixedSignals:
              (averages[ranked.first] - averages[ranked[1]]).abs() < 0.05,
          analysisCount: entry.value.length,
        ),
      );
    }
    result.sort((a, b) => b.day.compareTo(a.day));
    return result;
  }

  static List<MapEntry<String, double>> _normalizedEntries(
    EmotionScores scores,
  ) {
    double safe(double value) => value.isFinite && value > 0 ? value : 0;
    return [
      MapEntry('happiness', safe(scores.happiness)),
      MapEntry('calm', safe(scores.calm)),
      MapEntry('excitement', safe(scores.excitement)),
      MapEntry('curiosity', safe(scores.curiosity)),
      MapEntry('anxiety', safe(scores.anxiety)),
      MapEntry('fear', safe(scores.fear)),
      MapEntry('sadness', safe(scores.sadness)),
      MapEntry('discomfort', safe(scores.discomfort)),
    ];
  }
}
