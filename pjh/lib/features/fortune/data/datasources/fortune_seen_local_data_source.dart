import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 날짜(자정 경계) 기준 'YYYYMMDD' 키. 운세 시드·seen 키가 모두 이 값을
/// 단일 출처로 써야 자정 후 자동으로 새 운세/미확인으로 전환된다.
///
/// [now] 미지정 시 로컬 현재시각. UTC 가 아니라 로컬 기준이라 사용자의 자정에
/// 맞춰 날짜가 바뀐다(시드 규칙과 동일).
String fortuneDateKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}$mm$dd';
}

/// 운세 "오늘 확인함" 로컬 기록 + 과거 키 정리.
///
/// - 키: `fortune_seen_<petId>_<YYYYMMDD>` (pet 단위 분리 → 다견·다묘 독립).
/// - 날짜가 키에 들어가므로 자정이 지나면 "오늘 키"가 달라져 자동 미확인 전환.
/// - 과거 키는 1회 정리하되 **오늘 키는 보존**(다른 pet 의 오늘 키 포함).
abstract class FortuneSeenLocalDataSource {
  /// 해당 pet 의 [dateKey](오늘) 확인 여부.
  Future<bool> isSeen(String petId, String dateKey);

  /// 해당 pet 의 [dateKey](오늘) 를 확인함으로 기록.
  Future<void> markSeen(String petId, String dateKey);

  /// 과거 fortune_seen_* 키 정리(오늘 [todayKey] 로 끝나는 키는 보존).
  /// 앱/홈 진입 시 1회 호출 권장. 반환값 = 삭제한 키 수.
  Future<int> purgePastKeys(String todayKey);
}

class FortuneSeenLocalDataSourceImpl implements FortuneSeenLocalDataSource {
  final SharedPreferences prefs;

  FortuneSeenLocalDataSourceImpl({required this.prefs});

  static const String _prefix = 'fortune_seen_';

  String _key(String petId, String dateKey) => '$_prefix${petId}_$dateKey';

  @override
  Future<bool> isSeen(String petId, String dateKey) async {
    return prefs.getBool(_key(petId, dateKey)) ?? false;
  }

  @override
  Future<void> markSeen(String petId, String dateKey) async {
    await prefs.setBool(_key(petId, dateKey), true);
  }

  @override
  Future<int> purgePastKeys(String todayKey) async {
    // 오늘 키는 어떤 pet 이든 보존 — 접미사 '_<todayKey>' 로 끝나면 스킵.
    final suffix = '_$todayKey';
    final stale = prefs
        .getKeys()
        .where((k) => k.startsWith(_prefix) && !k.endsWith(suffix))
        .toList();
    for (final k in stale) {
      await prefs.remove(k);
    }
    return stale.length;
  }
}
