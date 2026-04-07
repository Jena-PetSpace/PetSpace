import 'dart:math' as math;
import 'package:equatable/equatable.dart';

class EmotionAnalysis extends Equatable {
  final String id;
  final String userId;
  final String? petId;
  final String? petName;
  final String imageUrl;
  final String localImagePath;
  final EmotionScores emotions;
  final double confidence;
  final DateTime analyzedAt;
  final String? memo;
  final List<String> tags;
  // 생리지표: 졸림 (감정 점수에서 분리)
  final bool isSleepy;

  const EmotionAnalysis({
    required this.id,
    required this.userId,
    this.petId,
    this.petName,
    required this.imageUrl,
    required this.localImagePath,
    required this.emotions,
    required this.confidence,
    required this.analyzedAt,
    this.memo,
    required this.tags,
    this.isSleepy = false,
  });

  factory EmotionAnalysis.empty() {
    return EmotionAnalysis(
      id: '',
      userId: '',
      petId: '',
      petName: null,
      imageUrl: '',
      localImagePath: '',
      emotions: const EmotionScores(
        happiness: 0.125,
        calm:      0.125,
        excitement:0.125,
        curiosity: 0.125,
        anxiety:   0.125,
        fear:      0.125,
        sadness:   0.125,
        discomfort:0.125,
      ),
      confidence: 0.0,
      analyzedAt: DateTime.now(),
      tags: const [],
      isSleepy: false,
    );
  }

  factory EmotionAnalysis.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysis(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      petId: json['pet_id'] as String? ?? '',
      petName: json['pet_name'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      localImagePath: json['local_image_path'] as String? ?? '',
      emotions: json['emotions'] != null
          ? EmotionScores.fromJson(json['emotions'] as Map<String, dynamic>)
          : const EmotionScores(
              happiness: 0.0, sadness: 0.0, anxiety: 0.0, curiosity: 0.0,
            ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.parse(json['analyzed_at'] as String)
          : DateTime.now(),
      memo: json['memo'] as String?,
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : [],
      isSleepy: json['is_sleepy'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pet_id': petId,
      'pet_name': petName,
      'image_url': imageUrl,
      'local_image_path': localImagePath,
      'emotions': emotions.toJson(),
      'confidence': confidence,
      'analyzed_at': analyzedAt.toIso8601String(),
      'memo': memo,
      'tags': tags,
      'is_sleepy': isSleepy,
    };
  }

  EmotionAnalysis copyWith({
    String? id,
    String? userId,
    String? petId,
    String? petName,
    String? imageUrl,
    String? localImagePath,
    EmotionScores? emotions,
    double? confidence,
    DateTime? analyzedAt,
    String? memo,
    List<String>? tags,
    bool? isSleepy,
  }) {
    return EmotionAnalysis(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      emotions: emotions ?? this.emotions,
      confidence: confidence ?? this.confidence,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      memo: memo ?? this.memo,
      tags: tags ?? this.tags,
      isSleepy: isSleepy ?? this.isSleepy,
    );
  }

  @override
  List<Object?> get props => [
        id, userId, petId, petName,
        imageUrl, localImagePath,
        emotions, confidence, analyzedAt,
        memo, tags, isSleepy,
      ];
}

// 부위별 분석 결과
class FacialFeature extends Equatable {
  final String state; // 예: "귀가 뒤로 눕혀짐"
  final String signal; // 예: "불안"

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
  // ── 기존 감정 (유지) ──────────────────────────────────────────
  final double happiness;
  final double sadness;
  final double anxiety;
  final double curiosity;

  // ── 신규 감정 (8종 확장) ──────────────────────────────────────
  final double calm;
  final double excitement;
  final double fear;
  final double discomfort;

  // ── deprecated: 생리지표로 분리됨 → isSleepy 사용 ─────────────
  @Deprecated('생리지표로 분리됨. EmotionAnalysis.isSleepy 사용')
  final double sleepiness;

  // ── 추가 분석 지표 (0~100 스케일) ────────────────────────────
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
    required this.curiosity,
    this.calm        = 0.0,
    this.excitement  = 0.0,
    this.fear        = 0.0,
    this.discomfort  = 0.0,
    // ignore: deprecated_member_use_from_same_package
    this.sleepiness  = 0.0,
    this.stressLevel = 0,
    this.activityLevel = 0,
    this.healthSignal = 'normal',
    this.comfortLevel = 0,
    this.facialFeatures,
    this.healthTips = const [],
    this.breedInsight,
  });

  // 8감정 합계 (sleepiness 제외)
  double get total =>
      happiness + calm + excitement + curiosity +
      anxiety + fear + sadness + discomfort;

  String get dominantEmotion {
    final scores = {
      'happiness':  happiness,
      'calm':       calm,
      'excitement': excitement,
      'curiosity':  curiosity,
      'anxiety':    anxiety,
      'fear':       fear,
      'sadness':    sadness,
      'discomfort': discomfort,
    };
    return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // A-2: 감정 복합도 (Shannon Entropy, 0.0~1.0) — 8종 기준
  double get complexityIndex {
    final values = [happiness, calm, excitement, curiosity,
                    anxiety, fear, sadness, discomfort]
        .where((v) => v > 0)
        .toList();
    if (values.isEmpty) return 0.0;
    double entropy = 0.0;
    for (final v in values) {
      entropy -= v * (math.log(v) / math.log(2));
    }
    // max entropy for 8 emotions = log2(8) = 3.0
    return (entropy / 3.0).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'happiness':  happiness,
      'calm':       calm,
      'excitement': excitement,
      'curiosity':  curiosity,
      'anxiety':    anxiety,
      'fear':       fear,
      'sadness':    sadness,
      'discomfort': discomfort,
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
    final healthTips =
        rawTips is List ? List<String>.from(rawTips) : <String>[];

    return EmotionScores(
      happiness:   (json['happiness']   as num?)?.toDouble() ?? 0.0,
      calm:        (json['calm']        as num?)?.toDouble() ?? 0.0,
      excitement:  (json['excitement']  as num?)?.toDouble() ?? 0.0,
      curiosity:   (json['curiosity']   as num?)?.toDouble() ?? 0.0,
      anxiety:     (json['anxiety']     as num?)?.toDouble() ?? 0.0,
      fear:        (json['fear']        as num?)?.toDouble() ?? 0.0,
      sadness:     (json['sadness']     as num?)?.toDouble() ?? 0.0,
      discomfort:  (json['discomfort']  as num?)?.toDouble() ?? 0.0,
      // ignore: deprecated_member_use_from_same_package
      sleepiness:  (json['sleepiness']  as num?)?.toDouble() ?? 0.0, // 하위 호환
      stressLevel:    (json['stress_level']   as num?)?.toInt() ?? 0,
      activityLevel:  (json['activity_level'] as num?)?.toInt() ?? 0,
      healthSignal:   json['health_signal']   as String? ?? 'normal',
      comfortLevel:   (json['comfort_level']  as num?)?.toInt() ?? 0,
      facialFeatures: facialFeatures,
      healthTips:     healthTips,
      breedInsight:   json['breed_insight'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'happiness':  happiness,
      'calm':       calm,
      'excitement': excitement,
      'curiosity':  curiosity,
      'anxiety':    anxiety,
      'fear':       fear,
      'sadness':    sadness,
      'discomfort': discomfort,
      'stress_level':    stressLevel,
      'activity_level':  activityLevel,
      'health_signal':   healthSignal,
      'comfort_level':   comfortLevel,
    };
    if (facialFeatures != null) {
      json['facial_features'] =
          facialFeatures!.map((k, v) => MapEntry(k, v.toJson()));
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
    double? calm,
    double? excitement,
    double? curiosity,
    double? anxiety,
    double? fear,
    double? sadness,
    double? discomfort,
    double? sleepiness,
    int? stressLevel,
    int? activityLevel,
    String? healthSignal,
    int? comfortLevel,
    Map<String, FacialFeature>? facialFeatures,
    List<String>? healthTips,
    String? breedInsight,
  }) {
    return EmotionScores(
      happiness:   happiness   ?? this.happiness,
      calm:        calm        ?? this.calm,
      excitement:  excitement  ?? this.excitement,
      curiosity:   curiosity   ?? this.curiosity,
      anxiety:     anxiety     ?? this.anxiety,
      fear:        fear        ?? this.fear,
      sadness:     sadness     ?? this.sadness,
      discomfort:  discomfort  ?? this.discomfort,
      // ignore: deprecated_member_use_from_same_package
      sleepiness:  sleepiness  ?? this.sleepiness,
      stressLevel:    stressLevel    ?? this.stressLevel,
      activityLevel:  activityLevel  ?? this.activityLevel,
      healthSignal:   healthSignal   ?? this.healthSignal,
      comfortLevel:   comfortLevel   ?? this.comfortLevel,
      facialFeatures: facialFeatures ?? this.facialFeatures,
      healthTips:     healthTips     ?? this.healthTips,
      breedInsight:   breedInsight   ?? this.breedInsight,
    );
  }

  @override
  List<Object?> get props => [
        happiness, calm, excitement, curiosity,
        anxiety, fear, sadness, discomfort,
        // ignore: deprecated_member_use_from_same_package
        sleepiness,
        stressLevel, activityLevel, healthSignal, comfortLevel,
        facialFeatures, healthTips, breedInsight,
      ];
}
