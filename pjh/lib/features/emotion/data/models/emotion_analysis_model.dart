import '../../domain/entities/emotion_analysis.dart';

class EmotionAnalysisModel extends EmotionAnalysis {
  const EmotionAnalysisModel({
    required super.id,
    required super.userId,
    required super.petId,
    required super.imageUrl,
    required super.localImagePath,
    required super.emotions,
    required super.confidence,
    required super.analyzedAt,
    super.memo,
    required super.tags,
    super.isSleepy = false,
  });

  factory EmotionAnalysisModel.fromEntity(EmotionAnalysis analysis) {
    return EmotionAnalysisModel(
      id: analysis.id,
      userId: analysis.userId,
      petId: analysis.petId,
      imageUrl: analysis.imageUrl,
      localImagePath: analysis.localImagePath,
      emotions: EmotionScoresModel.fromEntity(analysis.emotions),
      confidence: analysis.confidence,
      analyzedAt: analysis.analyzedAt,
      memo: analysis.memo,
      tags: analysis.tags,
      isSleepy: analysis.isSleepy,
    );
  }

  factory EmotionAnalysisModel.fromJson(Map<String, dynamic> data) {
    final emotionMap = data['emotion_analysis'] as Map<String, dynamic>? ?? {};
    return EmotionAnalysisModel(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      petId: data['pet_id'],
      imageUrl: data['image_url'] ?? '',
      localImagePath: '',
      emotions: EmotionScoresModel.fromMap(emotionMap),
      confidence: 0.8,
      analyzedAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      memo: data['memo'],
      tags: data['tags'] != null
          ? List<String>.from(data['tags'] as List)
          : const [],
      isSleepy: emotionMap['is_sleepy'] as bool? ?? false,
    );
  }

  factory EmotionAnalysisModel.fromMap(Map<String, dynamic> map) {
    return EmotionAnalysisModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      petId: map['petId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      localImagePath: map['localImagePath'] ?? '',
      emotions: EmotionScoresModel.fromMap(map['emotions'] ?? {}),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      analyzedAt: map['analyzedAt'] is String
          ? DateTime.parse(map['analyzedAt'])
          : DateTime.now(),
      memo: map['memo'],
      tags: List<String>.from(map['tags'] ?? []),
      isSleepy: map['is_sleepy'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'pet_id': petId,
      'image_url': imageUrl,
      'emotion_analysis': (emotions as EmotionScoresModel).toMap(),
      'memo': memo,
    };
  }

  @override
  EmotionAnalysisModel copyWith({
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
    return EmotionAnalysisModel(
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
      isSleepy: isSleepy ?? this.isSleepy,
    );
  }
}

class EmotionScoresModel extends EmotionScores {
  const EmotionScoresModel({
    required super.happiness,
    required super.sadness,
    required super.anxiety,
    required super.curiosity,
    super.calm        = 0.0,
    super.excitement  = 0.0,
    super.fear        = 0.0,
    super.discomfort  = 0.0,
    // ignore: deprecated_member_use_from_same_package
    super.sleepiness  = 0.0,
    super.stressLevel,
    super.activityLevel,
    super.healthSignal,
    super.comfortLevel,
    super.facialFeatures,
    super.healthTips,
    super.breedInsight,
  });

  factory EmotionScoresModel.fromEntity(EmotionScores scores) {
    return EmotionScoresModel(
      happiness:   scores.happiness,
      calm:        scores.calm,
      excitement:  scores.excitement,
      curiosity:   scores.curiosity,
      anxiety:     scores.anxiety,
      fear:        scores.fear,
      sadness:     scores.sadness,
      discomfort:  scores.discomfort,
      // ignore: deprecated_member_use_from_same_package
      sleepiness:  scores.sleepiness,
      stressLevel:   scores.stressLevel,
      activityLevel: scores.activityLevel,
      healthSignal:  scores.healthSignal,
      comfortLevel:  scores.comfortLevel,
      facialFeatures: scores.facialFeatures,
      healthTips:    scores.healthTips,
      breedInsight:  scores.breedInsight,
    );
  }

  factory EmotionScoresModel.fromMap(Map<String, dynamic> map) {
    // 부위별 분석
    Map<String, FacialFeature>? facialFeatures;
    final rawFeatures = map['facial_features'];
    if (rawFeatures is Map<String, dynamic>) {
      facialFeatures = rawFeatures.map((k, v) => MapEntry(
            k,
            v is Map<String, dynamic>
                ? FacialFeature.fromJson(v)
                : const FacialFeature(state: '', signal: ''),
          ));
    }

    // 건강 팁
    final rawTips = map['health_tips'];
    final healthTips =
        rawTips is List ? List<String>.from(rawTips) : <String>[];

    return EmotionScoresModel(
      happiness:   (map['happiness']  as num?)?.toDouble() ?? 0.0,
      calm:        (map['calm']       as num?)?.toDouble() ?? 0.0,
      excitement:  (map['excitement'] as num?)?.toDouble() ?? 0.0,
      curiosity:   (map['curiosity']  as num?)?.toDouble() ?? 0.0,
      anxiety:     (map['anxiety']    as num?)?.toDouble() ?? 0.0,
      fear:        (map['fear']       as num?)?.toDouble() ?? 0.0,
      sadness:     (map['sadness']    as num?)?.toDouble() ?? 0.0,
      discomfort:  (map['discomfort'] as num?)?.toDouble() ?? 0.0,
      // ignore: deprecated_member_use_from_same_package
      sleepiness:  (map['sleepiness'] as num?)?.toDouble() ?? 0.0, // 하위 호환
      stressLevel: (map['stress_level']   as num?)?.toInt() ?? 0,
      activityLevel: (map['activity_level'] as num?)?.toInt() ?? 0,
      healthSignal: map['health_signal'] as String? ?? 'normal',
      comfortLevel: (map['comfort_level'] as num?)?.toInt() ?? 0,
      facialFeatures: facialFeatures,
      healthTips: healthTips,
      breedInsight: map['breed_insight'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'happiness':  happiness,
      'calm':       calm,
      'excitement': excitement,
      'curiosity':  curiosity,
      'anxiety':    anxiety,
      'fear':       fear,
      'sadness':    sadness,
      'discomfort': discomfort,
      'stress_level':   stressLevel,
      'activity_level': activityLevel,
      'health_signal':  healthSignal,
      'comfort_level':  comfortLevel,
    };
    if (facialFeatures != null) {
      map['facial_features'] =
          facialFeatures!.map((k, v) => MapEntry(k, v.toJson()));
    }
    if (healthTips.isNotEmpty) {
      map['health_tips'] = healthTips;
    }
    if (breedInsight != null) {
      map['breed_insight'] = breedInsight;
    }
    return map;
  }

  @override
  EmotionScoresModel copyWith({
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
    return EmotionScoresModel(
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
      stressLevel:   stressLevel   ?? this.stressLevel,
      activityLevel: activityLevel ?? this.activityLevel,
      healthSignal:  healthSignal  ?? this.healthSignal,
      comfortLevel:  comfortLevel  ?? this.comfortLevel,
      facialFeatures: facialFeatures ?? this.facialFeatures,
      healthTips:    healthTips    ?? this.healthTips,
      breedInsight:  breedInsight  ?? this.breedInsight,
    );
  }
}
