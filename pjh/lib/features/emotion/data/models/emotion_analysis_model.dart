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
    );
  }

  factory EmotionAnalysisModel.fromJson(Map<String, dynamic> data) {
    return EmotionAnalysisModel(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      petId: data['pet_id'],
      imageUrl: data['image_url'] ?? '',
      localImagePath: '',
      emotions: EmotionScoresModel.fromMap(data['emotion_analysis'] ?? {}),
      confidence: 0.8,
      analyzedAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      memo: data['memo'],
      tags: data['tags'] != null
          ? List<String>.from(data['tags'] as List)
          : const [],
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
    String? imageUrl,
    String? localImagePath,
    EmotionScores? emotions,
    double? confidence,
    DateTime? analyzedAt,
    String? memo,
    List<String>? tags,
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
    );
  }
}

class EmotionScoresModel extends EmotionScores {
  const EmotionScoresModel({
    required super.happiness,
    required super.sadness,
    required super.anxiety,
    required super.sleepiness,
    required super.curiosity,
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
      happiness: scores.happiness,
      sadness: scores.sadness,
      anxiety: scores.anxiety,
      sleepiness: scores.sleepiness,
      curiosity: scores.curiosity,
      stressLevel: scores.stressLevel,
      activityLevel: scores.activityLevel,
      healthSignal: scores.healthSignal,
      comfortLevel: scores.comfortLevel,
      facialFeatures: scores.facialFeatures,
      healthTips: scores.healthTips,
      breedInsight: scores.breedInsight,
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
    final healthTips = rawTips is List
        ? List<String>.from(rawTips)
        : <String>[];

    return EmotionScoresModel(
      happiness: (map['happiness'] ?? 0.0).toDouble(),
      sadness: (map['sadness'] ?? 0.0).toDouble(),
      anxiety: (map['anxiety'] ?? 0.0).toDouble(),
      sleepiness: (map['sleepiness'] ?? 0.0).toDouble(),
      curiosity: (map['curiosity'] ?? 0.0).toDouble(),
      stressLevel: (map['stress_level'] ?? 0) is int
          ? map['stress_level'] ?? 0
          : (map['stress_level'] as num?)?.toInt() ?? 0,
      activityLevel: (map['activity_level'] ?? 0) is int
          ? map['activity_level'] ?? 0
          : (map['activity_level'] as num?)?.toInt() ?? 0,
      healthSignal: map['health_signal'] as String? ?? 'normal',
      comfortLevel: (map['comfort_level'] ?? 0) is int
          ? map['comfort_level'] ?? 0
          : (map['comfort_level'] as num?)?.toInt() ?? 0,
      facialFeatures: facialFeatures,
      healthTips: healthTips,
      breedInsight: map['breed_insight'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
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
      map['facial_features'] = facialFeatures!.map(
          (k, v) => MapEntry(k, v.toJson()));
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
    return EmotionScoresModel(
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
}
