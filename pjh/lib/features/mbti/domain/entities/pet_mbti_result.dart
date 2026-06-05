import 'package:equatable/equatable.dart';

/// MBTI 검사에서 사용하는 종 구분.
///
/// 반려동물 프로필의 [PetType]({dog, cat})과는 별개 개념으로, 종 정보가
/// 없거나 모호할 때 범용 문항([etc])으로 폴백하기 위해 별도 enum 으로 둔다.
enum MbtiSpecies { dog, cat, etc }

extension MbtiSpeciesX on MbtiSpecies {
  /// DB / JSON 에 저장되는 문자열 키 ('dog' / 'cat' / 'etc').
  String get key => name;

  static MbtiSpecies fromKey(String? key) {
    switch (key?.toLowerCase()) {
      case 'dog':
        return MbtiSpecies.dog;
      case 'cat':
        return MbtiSpecies.cat;
      default:
        return MbtiSpecies.etc;
    }
  }

  /// 반려동물 프로필 종 문자열('dog'/'cat'/...)을 MbtiSpecies 로 매핑.
  /// 모르는 값/없음 → etc 폴백. (PetType enum 과 분리된 매핑 레이어)
  static MbtiSpecies fromPetTypeString(String? petType) => fromKey(petType);
}

/// 한 응답: 문항 id + 선택한 옵션 인덱스(0~3).
///
/// 채점·복기는 저장된 content_version 의 questions[].options[optionIndex] 에서
/// pole/weight 를 읽어 해석한다.
class MbtiAnswer extends Equatable {
  final String questionId;
  final int optionIndex; // 0~3 (4지선다)

  const MbtiAnswer({
    required this.questionId,
    required this.optionIndex,
  });

  @override
  List<Object?> get props => [questionId, optionIndex];
}

/// 한 축의 양 극 카운트(축당 합 = 5).
///
/// 예: EI 축에서 E 4표 / I 1표 → AxisScore(positive: 'E', negative: 'I',
/// positiveCount: 4, negativeCount: 1).
class AxisScore extends Equatable {
  final String positivePole; // 예: 'E'
  final String negativePole; // 예: 'I'
  final int positiveCount;
  final int negativeCount;

  const AxisScore({
    required this.positivePole,
    required this.negativePole,
    required this.positiveCount,
    required this.negativeCount,
  });

  int get total => positiveCount + negativeCount;

  /// 우세 극 코드. 가중 점수(positiveCount/negativeCount)가 큰 쪽.
  /// 동점이면 축 기본극(negative = I/N/F/P)으로 폴백 — 채점기 type_code 와 일치.
  String get dominantPole =>
      positiveCount > negativeCount ? positivePole : negativePole;

  int get dominantCount =>
      positiveCount > negativeCount ? positiveCount : negativeCount;

  /// 우세 극 퍼센트 = 우세 점수 / 두 극 합 × 100, 반올림. (예: E7 I3 → 70%)
  /// 표시 전용. type_code 결정과 분리.
  int get dominantPercent =>
      total == 0 ? 0 : ((dominantCount / total) * 100).round();

  @override
  List<Object?> get props =>
      [positivePole, negativePole, positiveCount, negativeCount];
}

/// 반려동물 MBTI 검사 결과 (이력 1건).
///
/// 검사마다 새 결과로 생성되며 덮어쓰지 않는다(이력 보존). 최신 1건은
/// Repository 에서 created_at 내림차순으로 조회한다.
class PetMbtiResult extends Equatable {
  final String id;
  final String petId;
  final MbtiSpecies species;
  final String typeCode; // 4글자, 예: 'ENFP'
  final Map<String, AxisScore> axisScores; // key: 'EI' | 'SN' | 'TF' | 'JP'
  final List<MbtiAnswer> answers;
  final int contentVersion;
  final DateTime createdAt;

  const PetMbtiResult({
    required this.id,
    required this.petId,
    required this.species,
    required this.typeCode,
    required this.axisScores,
    required this.answers,
    required this.contentVersion,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        petId,
        species,
        typeCode,
        axisScores,
        answers,
        contentVersion,
        createdAt,
      ];
}
