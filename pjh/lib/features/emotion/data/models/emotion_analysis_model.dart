// Firebase 의존성 제거 - Supabase로 전환

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
      localImagePath: '', // 로컬 저장 경로는 클라이언트에서 관리
      emotions: EmotionScoresModel.fromMap(data['emotion_analysis'] ?? {}),
      confidence: 0.8, // 기본 신뢰도 값
      analyzedAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      memo: data['memo'],
      tags: const [], // 기본값
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
  });

  factory EmotionScoresModel.fromEntity(EmotionScores scores) {
    return EmotionScoresModel(
      happiness: scores.happiness,
      sadness: scores.sadness,
      anxiety: scores.anxiety,
      sleepiness: scores.sleepiness,
      curiosity: scores.curiosity,
    );
  }

  factory EmotionScoresModel.fromMap(Map<String, dynamic> map) {
    return EmotionScoresModel(
      happiness: (map['happiness'] ?? 0.0).toDouble(),
      sadness: (map['sadness'] ?? 0.0).toDouble(),
      anxiety: (map['anxiety'] ?? 0.0).toDouble(),
      sleepiness: (map['sleepiness'] ?? 0.0).toDouble(),
      curiosity: (map['curiosity'] ?? 0.0).toDouble(),
    );
  }

  @override
  Map<String, double> toMap() {
    return {
      'happiness': happiness,
      'sadness': sadness,
      'anxiety': anxiety,
      'sleepiness': sleepiness,
      'curiosity': curiosity,
    };
  }

  @override
  EmotionScoresModel copyWith({
    double? happiness,
    double? sadness,
    double? anxiety,
    double? sleepiness,
    double? curiosity,
  }) {
    return EmotionScoresModel(
      happiness: happiness ?? this.happiness,
      sadness: sadness ?? this.sadness,
      anxiety: anxiety ?? this.anxiety,
      sleepiness: sleepiness ?? this.sleepiness,
      curiosity: curiosity ?? this.curiosity,
    );
  }
}
