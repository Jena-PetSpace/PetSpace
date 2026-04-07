import 'dart:math' as math;
import '../../domain/entities/emotion_analysis.dart';

class EmotionInsights {
  final double wellbeingScore; // 0~100
  final double stabilityIndex; // 0~1.0
  final Map<String, double> emotionStability; // 각 감정별 안정성 (0~1)
  final bool hasEnoughData;
  final String emptyStateMessage;

  const EmotionInsights({
    required this.wellbeingScore,
    required this.stabilityIndex,
    required this.emotionStability,
    required this.hasEnoughData,
    this.emptyStateMessage = '',
  });

  static const empty = EmotionInsights(
    wellbeingScore: 0,
    stabilityIndex: 0,
    emotionStability: {},
    hasEnoughData: false,
    emptyStateMessage: '분석 기록이 부족해요. 3회 이상 분석하면 인사이트를 볼 수 있어요.',
  );
}

class EmotionInsightsService {
  static const int _minDataPoints = 3;

  EmotionInsights calculate(List<EmotionAnalysis> history) {
    if (history.length < _minDataPoints) {
      return EmotionInsights.empty;
    }

    // B-1: 웰빙 점수 = 긍정감정비율(40%) + 스트레스안정성(40%) + 감정변동안정성(20%)
    final wellbeing = _calculateWellbeing(history);

    // B-3: 감정별 안정성 (표준편차 기반)
    final emotionStability = _calculateEmotionStability(history);
    final avgStability = emotionStability.values.isNotEmpty
        ? emotionStability.values.reduce((a, b) => a + b) /
            emotionStability.length
        : 0.0;

    return EmotionInsights(
      wellbeingScore: wellbeing,
      stabilityIndex: avgStability,
      emotionStability: emotionStability,
      hasEnoughData: true,
    );
  }

  double _calculateWellbeing(List<EmotionAnalysis> history) {
    // 긍정 감정 비율: happiness + calm + excitement + curiosity*0.5
    double positiveRatioSum = 0;
    double stressSum = 0;

    for (final a in history) {
      final e = a.emotions;
      positiveRatioSum += e.happiness + e.calm + e.excitement + (e.curiosity * 0.5);
      stressSum += e.stressLevel;
    }

    final positiveRatio = (positiveRatioSum / history.length).clamp(0.0, 1.0);
    final avgStress = stressSum / history.length;
    final stressStability = 1.0 - (avgStress / 100);

    // 감정 변동 안정성: 8개 감정 변화폭 평균
    double totalVariation = 0;
    for (int i = 1; i < history.length; i++) {
      final cur  = history[i].emotions;
      final prev = history[i - 1].emotions;
      totalVariation +=
          (cur.happiness  - prev.happiness).abs()  +
          (cur.calm       - prev.calm).abs()       +
          (cur.excitement - prev.excitement).abs() +
          (cur.curiosity  - prev.curiosity).abs()  +
          (cur.anxiety    - prev.anxiety).abs()    +
          (cur.fear       - prev.fear).abs()       +
          (cur.sadness    - prev.sadness).abs()    +
          (cur.discomfort - prev.discomfort).abs();
    }
    final avgVariation = history.length > 1
        ? totalVariation / (history.length - 1) / 8 // 8개 감정
        : 0.0;
    final emotionStability = 1.0 - avgVariation.clamp(0.0, 1.0);

    final score =
        (positiveRatio * 40) + (stressStability * 40) + (emotionStability * 20);

    return score.clamp(0.0, 100.0);
  }

  Map<String, double> _calculateEmotionStability(
      List<EmotionAnalysis> history) {
    const emotionKeys = [
      'happiness', 'calm', 'excitement', 'curiosity',
      'anxiety', 'fear', 'sadness', 'discomfort',
    ];
    final result = <String, double>{};

    for (final emotion in emotionKeys) {
      final values = history.map((a) {
        final e = a.emotions;
        switch (emotion) {
          case 'happiness':  return e.happiness;
          case 'calm':       return e.calm;
          case 'excitement': return e.excitement;
          case 'curiosity':  return e.curiosity;
          case 'anxiety':    return e.anxiety;
          case 'fear':       return e.fear;
          case 'sadness':    return e.sadness;
          case 'discomfort': return e.discomfort;
          default:           return 0.0;
        }
      }).toList();

      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance =
          values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
              values.length;
      final stddev = math.sqrt(variance);

      result[emotion] = (1.0 - (stddev / 0.5)).clamp(0.0, 1.0);
    }

    return result;
  }
}
