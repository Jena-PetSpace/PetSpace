import '../../../mbti/domain/entities/pet_mbti_result.dart' show MbtiSpecies;
import '../entities/daily_fortune.dart';
import '../entities/fortune_content.dart';
import 'fortune_group.dart';

/// 이름 없을 때 {petName} 대체어. 조사 충돌을 피하려 콘텐츠 문구는 이름 뒤
/// 조사를 두지 않으므로 단순 문자열 치환만 한다.
const String kFortuneFallbackName = '우리 아이';

/// 별점 긍정 가중 분포 — 데일리 운세가 매일 낮은 점수로 우울해지지 않게,
/// 균등(1~5)이 아니라 3~5 가중으로 뽑는다.
///
/// 가중치 합 = 1+1+2+3+3 = 10. (별점1:1, 2:1, 3:2, 4:3, 5:3)
/// 인덱스 = 별점-1.
const List<int> kStarWeights = [1, 1, 2, 3, 3];

/// 반려동물 운세 결정적 생성기.
///
/// 외부 호출·서버 저장 없이 [baseSeed] = hash(petId + 'YYYYMMDD') 로부터
/// 종합운/세부 항목/럭키를 결정적으로 산출한다. 항목 간에는 서브시드를 분리해
/// (`baseSeed + ':' + suffix`) 서로 독립적으로 뽑힌다.
class FortuneGenerator {
  const FortuneGenerator();

  /// [dateKey] 는 'YYYYMMDD'(로컬). 같은 (petId, dateKey) → 항상 동일 결과.
  ///
  /// - [mbtiTypeCode]: pets.current_mbti_type 캐시. null/형식불일치 → default 종합운.
  /// - [petName]: 문구 {petName} 치환용. null/빈값 → '우리 아이'.
  DailyFortune generate({
    required String petId,
    required MbtiSpecies species,
    required String dateKey,
    required FortuneContent content,
    String? mbtiTypeCode,
    String? petName,
  }) {
    final baseSeed = _hash('$petId$dateKey');
    final name = (petName != null && petName.trim().isNotEmpty)
        ? petName.trim()
        : kFortuneFallbackName;

    // ── 종합운: 그룹 키(코드→순수계산) → 풀에서 결정적 pick ──
    final group = mbtiGroupOf(mbtiTypeCode); // null 이면 default 폴백
    final overallPool = content.overallPool(species, group);
    final overallRaw =
        _pick(overallPool, _hash('$baseSeed:overall'), fallback: '');
    final overall = _replaceName(overallRaw, name);

    // ── 세부 항목: 항목별 서브시드로 별점·문구 독립 산출 ──
    final items = <FortuneItemResult>[];
    final stars = <int>[];
    for (final item in content.itemsFor(species)) {
      final star = _weightedStar(_hash('$baseSeed:${item.key}:star'));
      final phrasePool = content.itemPhrasePool(item.key, star);
      final phraseRaw =
          _pick(phrasePool, _hash('$baseSeed:${item.key}:phrase'), fallback: '');
      stars.add(star);
      items.add(FortuneItemResult(
        key: item.key,
        label: item.label,
        star: star,
        phrase: _replaceName(phraseRaw, name),
      ));
    }

    // ── 종합 별점 = 세부 3개 평균(반올림). 별도 시드 안 씀(단일 출처) ──
    final overallStar = stars.isEmpty
        ? 3
        : (stars.reduce((a, b) => a + b) / stars.length).round();

    // ── 럭키: 종별 풀에서 각각 독립 pick ──
    final luckyTreat = _pick(
        content.luckyTreatPool(species), _hash('$baseSeed:luckyTreat'),
        fallback: '');
    final luckyPlace = _pick(
        content.luckyPlacePool(species), _hash('$baseSeed:luckyPlace'),
        fallback: '');

    return DailyFortune(
      petId: petId,
      species: species,
      dateKey: dateKey,
      overall: overall,
      items: items,
      overallStar: overallStar,
      luckyTreat: luckyTreat,
      luckyPlace: luckyPlace,
    );
  }

  // ── 결정적 해시·추출 ─────────────────────────────────────

  /// 문자열 → 32bit 결정적 해시 (FNV-1a). 플랫폼 무관·런타임 무관 고정.
  /// 음수 방지를 위해 부호 비트를 마스킹한다.
  int _hash(String s) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;
    for (int i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i);
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// 풀에서 시드로 1개 결정적 선택. 빈 풀이면 [fallback].
  String _pick(List<String> pool, int seed, {required String fallback}) {
    if (pool.isEmpty) return fallback;
    return pool[seed % pool.length];
  }

  /// 긍정 가중 분포에서 별점 1~5 결정적 산출.
  int _weightedStar(int seed) {
    final total = kStarWeights.reduce((a, b) => a + b); // 10
    int roll = seed % total;
    for (int i = 0; i < kStarWeights.length; i++) {
      if (roll < kStarWeights[i]) return i + 1; // 별점 = 인덱스+1
      roll -= kStarWeights[i];
    }
    return kStarWeights.length; // 이론상 도달 불가(안전 폴백 = 5)
  }

  /// {petName} 토큰을 이름으로 단순 치환(조사 미부착 전제).
  String _replaceName(String s, String name) =>
      s.replaceAll('{petName}', name);
}
