import 'package:equatable/equatable.dart';

import '../../../mbti/domain/entities/pet_mbti_result.dart' show MbtiSpecies;

/// 세부 항목 결과 1개 (라벨 + 별점 + 문구).
class FortuneItemResult extends Equatable {
  final String key; // 'insider' 등
  final String label; // '인싸력' 등
  final int star; // 1~5
  final String phrase; // 별점에 맞는 문구(이미 {petName} 치환 완료)

  const FortuneItemResult({
    required this.key,
    required this.label,
    required this.star,
    required this.phrase,
  });

  @override
  List<Object?> get props => [key, label, star, phrase];
}

/// 하루치 운세 결과 (결정적 생성물).
///
/// 같은 pet · 같은 날(YYYYMMDD) → 항상 동일. 서버 저장 없이 매번 재계산되며,
/// [dateKey] 는 생성 기준 날짜(로컬)다.
class DailyFortune extends Equatable {
  final String petId;
  final MbtiSpecies species;
  final String dateKey; // 'YYYYMMDD' (로컬 기준 시드 날짜)

  /// 종합운 문구 ({petName} 치환 완료).
  final String overall;

  /// 세부 항목 3개.
  final List<FortuneItemResult> items;

  /// 종합 별점 = 세부 3개 별점 평균(반올림). 홈 카드 이모지 기준.
  final int overallStar;

  final String luckyTreat;
  final String luckyPlace;

  const DailyFortune({
    required this.petId,
    required this.species,
    required this.dateKey,
    required this.overall,
    required this.items,
    required this.overallStar,
    required this.luckyTreat,
    required this.luckyPlace,
  });

  @override
  List<Object?> get props => [
        petId,
        species,
        dateKey,
        overall,
        items,
        overallStar,
        luckyTreat,
        luckyPlace,
      ];
}
