import 'package:equatable/equatable.dart';

import 'pet_mbti_result.dart';

/// 축 정의 (EI/SN/TF/JP). pos = 양극, neg = 음극.
class MbtiAxis extends Equatable {
  final String key; // 'EI' | 'SN' | 'TF' | 'JP'
  final String name; // 예: '사교성'
  final String posCode; // 예: 'E'
  final String posLabel; // 예: '외향'
  final String negCode; // 예: 'I'
  final String negLabel; // 예: '내향'

  const MbtiAxis({
    required this.key,
    required this.name,
    required this.posCode,
    required this.posLabel,
    required this.negCode,
    required this.negLabel,
  });

  @override
  List<Object?> get props => [key, name, posCode, posLabel, negCode, negLabel];
}

/// 문항 선택지(A/B).
class MbtiOption extends Equatable {
  final String label;
  final String pole; // 단일 글자 극 코드

  const MbtiOption({required this.label, required this.pole});

  @override
  List<Object?> get props => [label, pole];
}

/// 응답 강도 단계 (meta.answerIntensities). 예: strong(가중 2), mild(1).
class MbtiIntensity extends Equatable {
  final String id; // 'strong' | 'mild'
  final String label; // '확실히 그래요' 등
  final int weight; // 가중치

  const MbtiIntensity({
    required this.id,
    required this.label,
    required this.weight,
  });

  @override
  List<Object?> get props => [id, label, weight];
}

/// 한 문항.
class MbtiQuestion extends Equatable {
  final String id; // 예: 'dog_01'
  final String axis; // 'EI' | 'SN' | 'TF' | 'JP'
  final String text;
  final MbtiOption optionA;
  final MbtiOption optionB;

  const MbtiQuestion({
    required this.id,
    required this.axis,
    required this.text,
    required this.optionA,
    required this.optionB,
  });

  /// 선택('A'/'B')에 해당하는 극 코드.
  String poleForChoice(String choice) =>
      choice == 'A' ? optionA.pole : optionB.pole;

  @override
  List<Object?> get props => [id, axis, text, optionA, optionB];
}

/// 종별 유형 상세 (nickname·summary·desc·strength·caution·activity).
class MbtiTypeDetail extends Equatable {
  final String nickname;
  final String summary;
  final String desc;
  final String strength;
  final String caution;
  final String activity;

  const MbtiTypeDetail({
    required this.nickname,
    required this.summary,
    required this.desc,
    required this.strength,
    required this.caution,
    required this.activity,
  });

  @override
  List<Object?> get props =>
      [nickname, summary, desc, strength, caution, activity];
}

/// 16유형 1개 (그룹 + 종별 상세 3개).
class MbtiTypeInfo extends Equatable {
  final String code; // 'ENFP' 등
  final String group; // '분석가' | '외교관' | '관리자' | '탐험가'
  final Map<MbtiSpecies, MbtiTypeDetail> details;

  const MbtiTypeInfo({
    required this.code,
    required this.group,
    required this.details,
  });

  MbtiTypeDetail detailFor(MbtiSpecies species) =>
      details[species] ?? details[MbtiSpecies.etc]!;

  @override
  List<Object?> get props => [code, group, details];
}

/// 궁합 1건 (상대 유형 코드 + 이유).
class MbtiMatch extends Equatable {
  final String type;
  final String reason;

  const MbtiMatch({required this.type, required this.reason});

  @override
  List<Object?> get props => [type, reason];
}

/// 한 결과 유형의 궁합(강아지 1 + 고양이 1).
class MbtiCompatibility extends Equatable {
  final MbtiMatch dog;
  final MbtiMatch cat;

  const MbtiCompatibility({required this.dog, required this.cat});

  @override
  List<Object?> get props => [dog, cat];
}

/// 그룹 메타(색상 키 등).
class MbtiGroup extends Equatable {
  final String name; // '분석가' 등
  final String axesKey; // 'NT' | 'NF' | 'SJ' | 'SP'
  final String color; // 'purple' | 'coral' | 'navy' | 'teal'

  const MbtiGroup({
    required this.name,
    required this.axesKey,
    required this.color,
  });

  @override
  List<Object?> get props => [name, axesKey, color];
}

/// 앱 번들 JSON 전체를 표현하는 콘텐츠 묶음.
///
/// [version]은 채점·복기 해석 기준이 되는 콘텐츠 버전이다. 과거 결과를 복기할
/// 때는 항상 그 결과의 content_version 에 맞는 콘텐츠로 해석해야 한다.
class MbtiContent extends Equatable {
  final int version;
  final String disclaimer;
  final int questionsPerAxis;
  final Map<String, MbtiAxis> axes; // key: 'EI' ...
  final Map<String, MbtiGroup> groups; // key: 그룹명
  final Map<MbtiSpecies, List<MbtiQuestion>> questions;
  final Map<String, MbtiTypeInfo> types; // key: 'ENFP' ...
  final Map<String, MbtiCompatibility> compatibility; // key: 'ENFP' ...

  /// 응답 강도 단계(strong/mild). 비어있으면 단일 강도(가중 1) 2지선다로 동작.
  final List<MbtiIntensity> answerIntensities;

  const MbtiContent({
    required this.version,
    required this.disclaimer,
    required this.questionsPerAxis,
    required this.axes,
    required this.groups,
    required this.questions,
    required this.types,
    required this.compatibility,
    this.answerIntensities = const [],
  });

  /// 강도 id('strong'/'mild')의 가중치. 모르는 id 거나 강도 미사용이면 1.
  int weightForIntensity(String? intensityId) {
    if (intensityId == null) return 1;
    for (final i in answerIntensities) {
      if (i.id == intensityId) return i.weight;
    }
    return 1;
  }

  MbtiIntensity? intensityById(String id) {
    for (final i in answerIntensities) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<MbtiQuestion> questionsFor(MbtiSpecies species) =>
      questions[species] ?? const [];

  MbtiTypeInfo? typeInfo(String code) => types[code];

  MbtiCompatibility? compatibilityFor(String code) => compatibility[code];

  /// 그룹명으로 색상 키 조회. 없으면 null.
  String? colorForGroup(String groupName) => groups[groupName]?.color;

  @override
  List<Object?> get props => [
        version,
        disclaimer,
        questionsPerAxis,
        axes,
        groups,
        questions,
        types,
        compatibility,
        answerIntensities,
      ];
}
