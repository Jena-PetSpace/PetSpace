import '../../domain/entities/pet_mbti_result.dart';

/// 각 축의 (양극, 음극) 정의. axis_scores JSONB 직렬화/역직렬화에 사용.
const Map<String, List<String>> kMbtiAxisPoles = {
  'EI': ['E', 'I'],
  'SN': ['S', 'N'],
  'TF': ['T', 'F'],
  'JP': ['J', 'P'],
};

class PetMbtiResultModel extends PetMbtiResult {
  const PetMbtiResultModel({
    required super.id,
    required super.petId,
    required super.species,
    required super.typeCode,
    required super.axisScores,
    required super.answers,
    required super.contentVersion,
    required super.createdAt,
  });

  factory PetMbtiResultModel.fromEntity(PetMbtiResult e) {
    return PetMbtiResultModel(
      id: e.id,
      petId: e.petId,
      species: e.species,
      typeCode: e.typeCode,
      axisScores: e.axisScores,
      answers: e.answers,
      contentVersion: e.contentVersion,
      createdAt: e.createdAt,
    );
  }

  /// Supabase row → Model
  factory PetMbtiResultModel.fromJson(Map<String, dynamic> json) {
    return PetMbtiResultModel(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      species: MbtiSpeciesX.fromKey(json['species'] as String?),
      typeCode: json['type_code'] as String,
      axisScores: _parseAxisScores(json['axis_scores']),
      answers: _parseAnswers(json['answers']),
      contentVersion: (json['content_version'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// INSERT용 JSON (id/created_at 은 DB 기본값 사용).
  Map<String, dynamic> toInsertJson() {
    return {
      'pet_id': petId,
      'species': species.key,
      'type_code': typeCode,
      'axis_scores': axisScoresToJson(),
      'answers': answersToJson(),
      'content_version': contentVersion,
    };
  }

  /// axis_scores → {"EI":{"E":4,"I":1}, ...}
  Map<String, dynamic> axisScoresToJson() {
    final out = <String, dynamic>{};
    axisScores.forEach((axis, score) {
      out[axis] = {
        score.positivePole: score.positiveCount,
        score.negativePole: score.negativeCount,
      };
    });
    return out;
  }

  /// answers → [{"q_id":"dog_01","choice":"A","intensity":"strong"}, ...]
  /// (intensity 는 강도 모드에서만 존재. null 이면 키 생략)
  List<Map<String, dynamic>> answersToJson() {
    return answers
        .map((a) => {
              'q_id': a.questionId,
              'choice': a.choice,
              if (a.intensity != null) 'intensity': a.intensity,
            })
        .toList();
  }

  static Map<String, AxisScore> _parseAxisScores(dynamic raw) {
    final result = <String, AxisScore>{};
    if (raw is! Map) return result;
    raw.forEach((axisKey, counts) {
      final axis = axisKey as String;
      final poles = kMbtiAxisPoles[axis];
      if (poles == null || counts is! Map) return;
      final pos = poles[0];
      final neg = poles[1];
      result[axis] = AxisScore(
        positivePole: pos,
        negativePole: neg,
        positiveCount: (counts[pos] as num?)?.toInt() ?? 0,
        negativeCount: (counts[neg] as num?)?.toInt() ?? 0,
      );
    });
    return result;
  }

  static List<MbtiAnswer> _parseAnswers(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => MbtiAnswer(
              questionId: m['q_id'] as String? ?? '',
              choice: m['choice'] as String? ?? '',
              intensity: m['intensity'] as String?,
            ))
        .where((a) => a.questionId.isNotEmpty)
        .toList();
  }
}
