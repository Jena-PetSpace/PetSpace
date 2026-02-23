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

  // JSON serialization for Supabase
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
        id,
        userId,
        petId,
        imageUrl,
        localImagePath,
        emotions,
        confidence,
        analyzedAt,
        memo,
        tags,
      ];
}

class EmotionScores extends Equatable {
  final double happiness;
  final double sadness;
  final double anxiety;
  final double sleepiness;
  final double curiosity;

  const EmotionScores({
    required this.happiness,
    required this.sadness,
    required this.anxiety,
    required this.sleepiness,
    required this.curiosity,
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

  Map<String, double> toMap() {
    return {
      'happiness': happiness,
      'sadness': sadness,
      'anxiety': anxiety,
      'sleepiness': sleepiness,
      'curiosity': curiosity,
    };
  }

  // JSON serialization for Supabase
  factory EmotionScores.fromJson(Map<String, dynamic> json) {
    return EmotionScores(
      happiness: (json['happiness'] as num?)?.toDouble() ?? 0.0,
      sadness: (json['sadness'] as num?)?.toDouble() ?? 0.0,
      anxiety: (json['anxiety'] as num?)?.toDouble() ?? 0.0,
      sleepiness: (json['sleepiness'] as num?)?.toDouble() ?? 0.0,
      curiosity: (json['curiosity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'happiness': happiness,
      'sadness': sadness,
      'anxiety': anxiety,
      'sleepiness': sleepiness,
      'curiosity': curiosity,
    };
  }

  EmotionScores copyWith({
    double? happiness,
    double? sadness,
    double? anxiety,
    double? sleepiness,
    double? curiosity,
  }) {
    return EmotionScores(
      happiness: happiness ?? this.happiness,
      sadness: sadness ?? this.sadness,
      anxiety: anxiety ?? this.anxiety,
      sleepiness: sleepiness ?? this.sleepiness,
      curiosity: curiosity ?? this.curiosity,
    );
  }

  @override
  List<Object?> get props =>
      [happiness, sadness, anxiety, sleepiness, curiosity];
}
