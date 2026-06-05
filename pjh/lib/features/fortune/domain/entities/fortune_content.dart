import 'package:equatable/equatable.dart';

import '../../../mbti/domain/entities/pet_mbti_result.dart' show MbtiSpecies;

/// 세부 항목 정의 1개 (key + 표시 라벨).
///
/// 예: dog → 인싸력(insider)·사고력(trouble)·득템운(treat).
class FortuneItem extends Equatable {
  final String key; // 'insider' | 'trouble' | ... (itemPhrases 의 키)
  final String label; // '인싸력' 등 표시용

  const FortuneItem({required this.key, required this.label});

  @override
  List<Object?> get props => [key, label];
}

/// 앱 번들 운세 콘텐츠 전체 (`assets/data/pet_fortune_content_v{N}.json`).
///
/// 외부 호출 0 · DB 0. 운세는 이 콘텐츠 + 클라이언트 시드(pet_id+날짜)로
/// 결정적으로 생성된다. 저장은 하지 않으며 매번 동일 결과를 재계산한다.
class FortuneContent extends Equatable {
  final int version;
  final String disclaimer;

  /// 종별 세부 항목 3개 (dog/cat/etc).
  final Map<MbtiSpecies, List<FortuneItem>> items;

  /// 종합운 풀: species → group('default'|'분석가'|'외교관'|'관리자'|'탐험가') → 문구 리스트.
  final Map<MbtiSpecies, Map<String, List<String>>> overall;

  /// 항목 문구 풀: itemKey → 별점('1'~'5') → 문구 리스트.
  final Map<String, Map<int, List<String>>> itemPhrases;

  /// 럭키 간식 풀: species → 후보 리스트.
  final Map<MbtiSpecies, List<String>> luckyTreat;

  /// 럭키 플레이스 풀: species → 후보 리스트.
  final Map<MbtiSpecies, List<String>> luckyPlace;

  const FortuneContent({
    required this.version,
    required this.disclaimer,
    required this.items,
    required this.overall,
    required this.itemPhrases,
    required this.luckyTreat,
    required this.luckyPlace,
  });

  /// 종별 세부 항목(없으면 빈 리스트 — 호출부에서 etc 폴백 권장).
  List<FortuneItem> itemsFor(MbtiSpecies species) => items[species] ?? const [];

  /// 종합운 풀 조회. [group] 이 없거나 풀이 비면 'default' 로 폴백.
  /// (MBTI 캐시 null → group=null → default.)
  List<String> overallPool(MbtiSpecies species, String? group) {
    final byGroup = overall[species] ?? const {};
    final g = (group != null && (byGroup[group]?.isNotEmpty ?? false))
        ? group
        : 'default';
    return byGroup[g] ?? const [];
  }

  /// 항목 문구 풀 조회 (별점 1~5).
  List<String> itemPhrasePool(String itemKey, int star) =>
      itemPhrases[itemKey]?[star] ?? const [];

  List<String> luckyTreatPool(MbtiSpecies species) =>
      luckyTreat[species] ?? const [];

  List<String> luckyPlacePool(MbtiSpecies species) =>
      luckyPlace[species] ?? const [];

  @override
  List<Object?> get props => [
        version,
        disclaimer,
        items,
        overall,
        itemPhrases,
        luckyTreat,
        luckyPlace,
      ];
}
