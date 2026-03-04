import 'dart:math' as math;
import 'package:equatable/equatable.dart';

class EmotionAnalysis extends Equatable {
  final String id;
  final String userId;
  final String? petId;
  final String imageUrl;
  final String localImagePath;
  final EmotionScores emotions;
  final double confidence;
  final DateTime analyzedAt;
  final String? memo;
  final List<String> tags;

  const EmotionAnalysis({
    required this.id,
    required this.userId,
    this.petId,
    required this.imageUrl,
    required this.localImagePath,
    required this.emotions,
    required this.confidence,
    required this.analyzedAt,
    this.memo,
    required this.tags,
  });

  factory EmotionAnalysis.empty() {
    return EmotionAnalysis(
      id: '',
      userId: '',
      petId: '',
      imageUrl: '',
      localImagePath: '',
      emotions: const EmotionScores(
        happiness: 0.5,
        sadness: 0.2,
        anxiety: 0.1,
        sleepiness: 0.1,
        curiosity: 0.1,
      ),
      confidence: 0.0,
      analyzedAt: DateTime.now(),
      tags: const [],
    );
  }

  factory EmotionAnalysis.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysis(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      petId: json['pet_id'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      localImagePath: json['local_image_path'] as String? ?? '',
      emotions: json['emotions'] != null
          ? EmotionScores.fromJson(json['emotions'] as Map<String, dynamic>)
          : const EmotionScores(
              happiness: 0.0,
              sadness: 0.0,
              anxiety: 0.0,
              sleepiness: 0.0,
              curiosity: 0.0,
            ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'] as String)
          : DateTime.now(),
      memo: json['memo'] as String?,
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pet_id': petId,
      'image_url': imageUrl,
      'local_image_path': localImagePath,
      'emotions': emotions.toJson(),
      'confidence': confidence,
      'analyzed_at': analyzedAt.toIso8601String(),
      'memo': memo,
      'tags': tags,
    };
  }

  EmotionAnalysis copyWith({
    String? id,
    String? userId,
    String? petId,
    String? imageUrl,
    String? localImagePath,
    EmotionScores? emotions,
    double? confidence,
    DateTime? analyzedAt,
    String? memo,
    List<String>? tags,
  }) {
    return EmotionAnalysis(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      petId: petId ?? this.petId,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      emotions: emotions ?? this.emotions,
      confidence: confidence ?? this.confidence,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      memo: memo ?? this.memo,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, petId, imageUrl, localImagePath,
        emotions, confidence, analyzedAt, memo, tags,
      ];
}

// 부위별 분석 결과
class FacialFeature extends Equatable {
  final String state;   // 예: "귀가 뒤로 눕혀짐"
  final String signal;  // 예: "불안"

  const FacialFeature({required this.state, required this.signal});

  factory FacialFeature.fromJson(Map<String, dynamic> json) => FacialFeature(
    state: json['state'] as String? ?? '',
    signal: json['signal'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'state': state, 'signal': signal};

  @override
  List<Object?> get props => [state, signal];
}

class EmotionScores extends Equatable {
  final double happiness;
  final double sadness;
  final double anxiety;
  final double sleepiness;
  final double curiosity;

  // 추가 분석 지표 (0~100 스케일)
  final int stressLevel;
  final int activityLevel;
  final String healthSignal;
  final int comfortLevel;

  // A-1: 부위별 분석
  final Map<String, FacialFeature>? facialFeatures;
  // A-3: 건강 관련 팁
  final List<String> healthTips;
  // A-6: 품종 기반 해석
  final String? breedInsight;

  const EmotionScores({
    required this.happiness,
    required this.sadness,
    required this.anxiety,
    required this.sleepiness,
    required this.curiosity,
    this.stressLevel = 0,
    this.activityLevel = 0,
    this.healthSignal = 'normal',
    this.comfortLevel = 0,
    this.facialFeatures,
    this.healthTips = const [],
    this.breedInsight,
  });

  double get total => happiness + sadness + anxiety + sleepiness + curiosity;

  String get dominantEmotion {
    final emotions = {
      'happiness': happiness,
      'sadness': sadness,
      'anxiety': anxiety,
      'sleepiness': sleepiness,
      'curiosity': curiosity,
    };
    return emotions.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // A-2: 감정 복합도 (Shannon Entropy, 0.0~1.0)
  double get complexityIndex {
    final values = [happiness, sadness, anxiety, sleepiness, curiosity]
        .where((v) => v > 0).toList();
    if (values.isEmpty) return 0.0;
    double entropy = 0.0;
    for (final v in values) {
      entropy -= v * (math.log(v) / math.log(2));
    }
    // max entropy for 5 emotions = log2(5) ~= 2.322
    return (entropy / 2.322).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'happiness': happiness,
      'sadness': sadness,
      'anxiety': anxiety,
      'sleepiness': sleepiness,
      'curiosity': curiosity,
    };
  }

  factory EmotionScores.fromJson(Map<String, dynamic> json) {
    // 부위별 분석 파싱
    Map<String, FacialFeature>? facialFeatures;
    final rawFeatures = json['facial_features'];
    if (rawFeatures is Map<String, dynamic>) {
      facialFeatures = rawFeatures.map((k, v) => MapEntry(
        k,
        v is Map<String, dynamic>
            ? FacialFeature.fromJson(v)
            : const FacialFeature(state: '', signal: ''),
      ));
    }

    // 건강 팁 파싱
    final rawTips = json['health_tips'];
    final healthTips = rawTips is List
        ? List<String>.from(rawTips)
        : <String>[];

    return EmotionScores(
      happiness: (json['happiness'] as num?)?.toDouble() ?? 0.0,
      sadness: (json['sadness'] as num?)?.toDouble() ?? 0.0,
      anxiety: (json['anxiety'] as num?)?.toDouble() ?? 0.0,
      sleepiness: (json['sleepiness'] as num?)?.toDouble() ?? 0.0,
      curiosity: (json['curiosity'] as num?)?.toDouble() ?? 0.0,
      stressLevel: (json['stress_level'] as num?)?.toInt() ?? 0,
      activityLevel: (json['activity_level'] as num?)?.toInt() ?? 0,
      healthSignal: json['health_signal'] as String? ?? 'normal',
      comfortLevel: (json['comfort_level'] as num?)?.toInt() ?? 0,
      facialFeatures: facialFeatures,
      healthTips: healthTips,
      breedInsight: json['breed_insight'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'happiness': happiness,
      'sadness': sadness,
      'anxiety': anxiety,
      'sleepiness': sleepiness,
      'curiosity': curiosity,
      'stress_level': stressLevel,
      'activity_level': activityLevel,
      'health_signal': healthSignal,
      'comfort_level': comfortLevel,
    };
    if (facialFeatures != null) {
      json['facial_features'] = facialFeatures!.map(
          (k, v) => MapEntry(k, v.toJson()));
    }
    if (healthTips.isNotEmpty) {
      json['health_tips'] = healthTips;
    }
    if (breedInsight != null) {
      json['breed_insight'] = breedInsight;
    }
    return json;
  }

  EmotionScores copyWith({
    double? happiness,
    double? sadness,
    double? anxiety,
    double? sleepiness,
    double? curiosity,
    int? stressLevel,
    int? activityLevel,
    String? healthSignal,
    int? comfortLevel,
    Map<String, FacialFeature>? facialFeatures,
    List<String>? healthTips,
    String? breedInsight,
  }) {
    return EmotionScores(
      happiness: happiness ?? this.happiness,
      sadness: sadness ?? this.sadness,
      anxiety: anxiety ?? this.anxiety,
      sleepiness: sleepiness ?? this.sleepiness,
      curiosity: curiosity ?? this.curiosity,
      stressLevel: stressLevel ?? this.stressLevel,
      activityLevel: activityLevel ?? this.activityLevel,
      healthSignal: healthSignal ?? this.healthSignal,
      comfortLevel: comfortLevel ?? this.comfortLevel,
      facialFeatures: facialFeatures ?? this.facialFeatures,
      healthTips: healthTips ?? this.healthTips,
      breedInsight: breedInsight ?? this.breedInsight,
    );
  }

  @override
  List<Object?> get props => [
        happiness, sadness, anxiety, sleepiness, curiosity,
        stressLevel, activityLevel, healthSignal, comfortLevel,
        facialFeatures, healthTips, breedInsight,
      ];
}
