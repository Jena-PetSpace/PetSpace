import '../../domain/entities/emotion_analysis.dart';

class EmotionTrendService {
  static final EmotionTrendService _instance = EmotionTrendService._internal();
  factory EmotionTrendService() => _instance;
  EmotionTrendService._internal();

  // Analyze emotion trends over time
  EmotionTrend analyzeTrend(List<EmotionAnalysis> analyses) {
    if (analyses.length < 2) {
      return EmotionTrend.insufficient();
    }

    // Sort by date
    analyses.sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));

    final trend = _calculateTrend(analyses);
    final patterns = _detectPatterns(analyses);
    final insights = _generateInsights(analyses, trend, patterns);
    final recommendations = _generateRecommendations(analyses, trend, patterns);

    return EmotionTrend(
      analyses: analyses,
      trendDirection: trend.direction,
      trendStrength: trend.strength,
      dominantEmotion: _findDominantEmotion(analyses),
      patterns: patterns,
      insights: insights,
      recommendations: recommendations,
      periodStart: analyses.first.analyzedAt,
      periodEnd: analyses.last.analyzedAt,
    );
  }

  TrendData _calculateTrend(List<EmotionAnalysis> analyses) {
    final scores = analyses.map((a) => _calculateOverallScore(a)).toList();

    if (scores.length < 2) {
      return TrendData(TrendDirection.stable, 0.0);
    }

    // Calculate linear regression
    final n = scores.length;
    final xSum = (n * (n - 1)) / 2; // 0 + 1 + 2 + ... + (n-1)
    final ySum = scores.reduce((a, b) => a + b);
    final xySum = scores
        .asMap()
        .entries
        .map((entry) => entry.key * entry.value)
        .reduce((a, b) => a + b);
    final xSquareSum = (n * (n - 1) * (2 * n - 1)) / 6;

    final slope = (n * xySum - xSum * ySum) / (n * xSquareSum - xSum * xSum);
    final strength = slope.abs();

    TrendDirection direction;
    if (slope > 0.1) {
      direction = TrendDirection.improving;
    } else if (slope < -0.1) {
      direction = TrendDirection.declining;
    } else {
      direction = TrendDirection.stable;
    }

    return TrendData(direction, strength.clamp(0.0, 1.0));
  }

  double _calculateOverallScore(EmotionAnalysis analysis) {
    // Weight positive emotions higher
    final emotions = analysis.emotions;

    // Calculate score based on emotion values
    double score = 0.5; // neutral baseline

    // Add positive emotions
    score += emotions.happiness * 0.5;
    score += emotions.curiosity * 0.3;

    // Subtract negative emotions
    score -= emotions.sadness * 0.5;
    score -= emotions.anxiety * 0.4;

    // Sleepiness is neutral

    return score.clamp(0.0, 1.0);
  }

  String _findDominantEmotion(List<EmotionAnalysis> analyses) {
    final emotionTotals = <String, double>{
      'happiness': 0.0,
      'sadness': 0.0,
      'anxiety': 0.0,
      'sleepiness': 0.0,
      'curiosity': 0.0,
    };

    for (final analysis in analyses) {
      final emotions = analysis.emotions;
      emotionTotals['happiness'] =
          emotionTotals['happiness']! + emotions.happiness;
      emotionTotals['sadness'] = emotionTotals['sadness']! + emotions.sadness;
      emotionTotals['anxiety'] = emotionTotals['anxiety']! + emotions.anxiety;
      emotionTotals['sleepiness'] =
          emotionTotals['sleepiness']! + emotions.sleepiness;
      emotionTotals['curiosity'] =
          emotionTotals['curiosity']! + emotions.curiosity;
    }

    return emotionTotals.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  List<EmotionPattern> _detectPatterns(List<EmotionAnalysis> analyses) {
    final patterns = <EmotionPattern>[];

    // Time-based patterns
    patterns.addAll(_detectTimePatterns(analyses));

    // Sequence patterns
    patterns.addAll(_detectSequencePatterns(analyses));

    // Cyclical patterns
    patterns.addAll(_detectCyclicalPatterns(analyses));

    return patterns;
  }

  List<EmotionPattern> _detectTimePatterns(List<EmotionAnalysis> analyses) {
    final patterns = <EmotionPattern>[];
    final hourlyEmotions = <int, List<String>>{};

    for (final analysis in analyses) {
      final hour = analysis.analyzedAt.hour;
      hourlyEmotions[hour] ??= [];
      hourlyEmotions[hour]!.add(_getPrimaryEmotion(analysis));
    }

    // Find consistent patterns by time of day
    for (final entry in hourlyEmotions.entries) {
      final hour = entry.key;
      final emotions = entry.value;

      if (emotions.length >= 3) {
        final dominantEmotion = _findMostFrequent(emotions);
        final frequency = emotions.where((e) => e == dominantEmotion).length /
            emotions.length;

        if (frequency > 0.6) {
          String timeOfDay;
          if (hour >= 6 && hour < 12) {
            timeOfDay = '아침';
          } else if (hour >= 12 && hour < 18) {
            timeOfDay = '오후';
          } else if (hour >= 18 && hour < 22) {
            timeOfDay = '저녁';
          } else {
            timeOfDay = '밤';
          }

          patterns.add(EmotionPattern(
            type: PatternType.timeOfDay,
            description: '$timeOfDay 시간대에 주로 $dominantEmotion 감정을 보입니다',
            confidence: frequency,
            timeFrame: timeOfDay,
            emotion: dominantEmotion,
          ));
        }
      }
    }

    return patterns;
  }

  List<EmotionPattern> _detectSequencePatterns(List<EmotionAnalysis> analyses) {
    final patterns = <EmotionPattern>[];

    if (analyses.length < 3) return patterns;

    // Look for sequences like "sad -> neutral -> happy"
    for (int i = 0; i < analyses.length - 2; i++) {
      final emotion1 = _getPrimaryEmotion(analyses[i]);
      final emotion2 = _getPrimaryEmotion(analyses[i + 1]);
      final emotion3 = _getPrimaryEmotion(analyses[i + 2]);

      // Recovery pattern: negative -> neutral -> positive
      if (_isNegative(emotion1) &&
          _isNeutral(emotion2) &&
          _isPositive(emotion3)) {
        patterns.add(EmotionPattern(
          type: PatternType.recovery,
          description: '부정적인 감정에서 빠르게 회복되는 패턴을 보입니다',
          confidence: 0.8,
          sequence: [emotion1, emotion2, emotion3],
        ));
      }

      // Stress pattern: positive -> negative -> negative
      if (_isPositive(emotion1) &&
          _isNegative(emotion2) &&
          _isNegative(emotion3)) {
        patterns.add(EmotionPattern(
          type: PatternType.stress,
          description: '스트레스로 인한 감정 악화 패턴이 관찰됩니다',
          confidence: 0.7,
          sequence: [emotion1, emotion2, emotion3],
        ));
      }
    }

    return patterns;
  }

  List<EmotionPattern> _detectCyclicalPatterns(List<EmotionAnalysis> analyses) {
    final patterns = <EmotionPattern>[];

    if (analyses.length < 7) return patterns;

    // Weekly pattern detection
    final weeklyEmotions = <int, List<String>>{};

    for (final analysis in analyses) {
      final dayOfWeek = analysis.analyzedAt.weekday;
      weeklyEmotions[dayOfWeek] ??= [];
      weeklyEmotions[dayOfWeek]!.add(_getPrimaryEmotion(analysis));
    }

    // Check for Monday blues, weekend happiness, etc.
    final mondayEmotions = weeklyEmotions[1] ?? [];
    // final fridayEmotions = weeklyEmotions[5] ?? []; // Currently unused
    final weekendEmotions = [
      ...(weeklyEmotions[6] ?? []),
      ...(weeklyEmotions[7] ?? [])
    ];

    if (mondayEmotions.isNotEmpty &&
        mondayEmotions.where(_isNegative).length / mondayEmotions.length >
            0.6) {
      patterns.add(EmotionPattern(
        type: PatternType.weekly,
        description: '월요일에 부정적인 감정을 자주 경험합니다 (월요병)',
        confidence: 0.7,
        timeFrame: '월요일',
      ));
    }

    if (weekendEmotions.isNotEmpty &&
        weekendEmotions.where(_isPositive).length / weekendEmotions.length >
            0.6) {
      patterns.add(EmotionPattern(
        type: PatternType.weekly,
        description: '주말에 긍정적인 감정을 자주 경험합니다',
        confidence: 0.7,
        timeFrame: '주말',
      ));
    }

    return patterns;
  }

  String _getPrimaryEmotion(EmotionAnalysis analysis) {
    final emotions = analysis.emotions;

    // Find the emotion with highest value
    final emotionMap = {
      'happiness': emotions.happiness,
      'sadness': emotions.sadness,
      'anxiety': emotions.anxiety,
      'sleepiness': emotions.sleepiness,
      'curiosity': emotions.curiosity,
    };

    return emotionMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _findMostFrequent(List<String> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts[item] = (counts[item] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  bool _isPositive(String emotion) {
    const positiveEmotions = ['happiness', 'curiosity'];
    return positiveEmotions.contains(emotion.toLowerCase());
  }

  bool _isNegative(String emotion) {
    const negativeEmotions = ['sadness', 'anxiety'];
    return negativeEmotions.contains(emotion.toLowerCase());
  }

  bool _isNeutral(String emotion) {
    const neutralEmotions = ['sleepiness'];
    return neutralEmotions.contains(emotion.toLowerCase());
  }

  List<String> _generateInsights(List<EmotionAnalysis> analyses,
      TrendData trend, List<EmotionPattern> patterns) {
    final insights = <String>[];

    // Trend insights
    switch (trend.direction) {
      case TrendDirection.improving:
        insights.add('최근 감정 상태가 전반적으로 개선되고 있습니다.');
        break;
      case TrendDirection.declining:
        insights.add('최근 감정 상태에 주의가 필요합니다.');
        break;
      case TrendDirection.stable:
        insights.add('감정 상태가 안정적으로 유지되고 있습니다.');
        break;
    }

    // Pattern insights
    final timePatterns =
        patterns.where((p) => p.type == PatternType.timeOfDay).toList();
    if (timePatterns.isNotEmpty) {
      insights.add('특정 시간대에 일정한 감정 패턴을 보입니다.');
    }

    final recoveryPatterns =
        patterns.where((p) => p.type == PatternType.recovery).toList();
    if (recoveryPatterns.isNotEmpty) {
      insights.add('부정적인 감정에서 빠른 회복력을 보입니다.');
    }

    final stressPatterns =
        patterns.where((p) => p.type == PatternType.stress).toList();
    if (stressPatterns.isNotEmpty) {
      insights.add('스트레스 관리에 더 많은 관심이 필요할 수 있습니다.');
    }

    // Emotion diversity insight
    final uniqueEmotions = <String>{};
    for (final analysis in analyses) {
      uniqueEmotions.add(_getPrimaryEmotion(analysis));
    }

    if (uniqueEmotions.length > 6) {
      insights.add('다양한 감정을 경험하며 풍부한 정서적 삶을 살고 있습니다.');
    } else if (uniqueEmotions.length < 3) {
      insights.add('감정 표현의 다양성을 늘려보는 것이 도움될 수 있습니다.');
    }

    return insights;
  }

  List<String> _generateRecommendations(List<EmotionAnalysis> analyses,
      TrendData trend, List<EmotionPattern> patterns) {
    final recommendations = <String>[];

    // Trend-based recommendations
    if (trend.direction == TrendDirection.declining) {
      recommendations.add('명상이나 요가 같은 마음챙김 활동을 시도해보세요.');
      recommendations.add('가까운 사람들과 시간을 보내는 것이 도움될 수 있습니다.');
    }

    // Pattern-based recommendations
    final mondayBlues = patterns.any(
        (p) => p.description.contains('월요일') && p.description.contains('부정'));
    if (mondayBlues) {
      recommendations.add('일요일 저녁에 다음 주를 준비하는 루틴을 만들어보세요.');
      recommendations.add('월요일 아침에 좋아하는 활동을 계획해보세요.');
    }

    final stressPatterns =
        patterns.where((p) => p.type == PatternType.stress).toList();
    if (stressPatterns.isNotEmpty) {
      recommendations.add('스트레스 해소를 위한 취미활동을 찾아보세요.');
      recommendations.add('규칙적인 운동이 감정 관리에 도움될 수 있습니다.');
    }

    // General recommendations
    final dominantEmotion = _findDominantEmotion(analyses);
    if (_isNegative(dominantEmotion)) {
      recommendations.add('긍정적인 활동이나 취미를 늘려보세요.');
      recommendations.add('충분한 수면과 규칙적인 생활 패턴을 유지해보세요.');
    }

    // Add personalized recommendations based on analysis frequency
    if (analyses.length > 20) {
      recommendations.add('꾸준한 감정 기록이 훌륭합니다. 이 습관을 계속 유지하세요.');
    } else {
      recommendations.add('더 자주 감정을 기록해보면 패턴을 더 잘 파악할 수 있습니다.');
    }

    return recommendations;
  }
}

// Data classes
class EmotionTrend {
  final List<EmotionAnalysis> analyses;
  final TrendDirection trendDirection;
  final double trendStrength;
  final String dominantEmotion;
  final List<EmotionPattern> patterns;
  final List<String> insights;
  final List<String> recommendations;
  final DateTime periodStart;
  final DateTime periodEnd;

  EmotionTrend({
    required this.analyses,
    required this.trendDirection,
    required this.trendStrength,
    required this.dominantEmotion,
    required this.patterns,
    required this.insights,
    required this.recommendations,
    required this.periodStart,
    required this.periodEnd,
  });

  factory EmotionTrend.insufficient() {
    return EmotionTrend(
      analyses: [],
      trendDirection: TrendDirection.stable,
      trendStrength: 0.0,
      dominantEmotion: 'neutral',
      patterns: [],
      insights: ['분석을 위해 더 많은 감정 기록이 필요합니다.'],
      recommendations: ['꾸준히 감정을 기록해주세요.'],
      periodStart: DateTime.now(),
      periodEnd: DateTime.now(),
    );
  }
}

class TrendData {
  final TrendDirection direction;
  final double strength;

  TrendData(this.direction, this.strength);
}

enum TrendDirection {
  improving,
  declining,
  stable,
}

class EmotionPattern {
  final PatternType type;
  final String description;
  final double confidence;
  final String? timeFrame;
  final String? emotion;
  final List<String>? sequence;

  EmotionPattern({
    required this.type,
    required this.description,
    required this.confidence,
    this.timeFrame,
    this.emotion,
    this.sequence,
  });
}

enum PatternType {
  timeOfDay,
  weekly,
  recovery,
  stress,
  cyclical,
}
