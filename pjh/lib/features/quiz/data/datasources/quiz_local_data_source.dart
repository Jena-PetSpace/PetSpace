import 'dart:math' show Random;

import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 날짜(자정 경계) 기준 'YYYYMMDD' 키. done 게이팅·스트릭이 모두 이 값을
/// 단일 출처로 써야 자정 후 자동으로 "오늘 미완료"로 전환된다.
///
/// [now] 미지정 시 로컬 현재시각. UTC 가 아니라 로컬 기준이라 사용자의 자정에
/// 맞춰 날짜가 바뀐다(운세 seen 키와 동일 규칙).
String quizDateKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}$mm$dd';
}

/// 두 'YYYYMMDD' 키의 날짜 차이(b - a, 일 단위). 문자열 비교가 아니라 실제
/// 날짜 차이로 스트릭을 계산하기 위함(월·연 경계 안전). 파싱 실패 시 null.
int? quizDayDiff(String a, String b) {
  final da = _parseDateKey(a);
  final db = _parseDateKey(b);
  if (da == null || db == null) return null;
  return db.difference(da).inDays;
}

DateTime? _parseDateKey(String key) {
  if (key.length != 8) return null;
  final y = int.tryParse(key.substring(0, 4));
  final m = int.tryParse(key.substring(4, 6));
  final d = int.tryParse(key.substring(6, 8));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// O/X 퀴즈 로컬 상태(개인 순열 시드·진행 커서·완료 게이팅·스트릭).
///
/// DB·서버 0, shared_preferences 만 사용. 키:
/// - `quiz_seed`           개인 순열 시드(최초 1회 랜덤 생성·고정).
/// - `quiz_cursor`         진행 커서(완료한 문항 수만큼만 전진). 270 도달 시 재셔플+0.
/// - `quiz_done_<YYYYMMDD>` 그 날 세트 완료 여부(하루 1세트 게이팅).
/// - `quiz_streak`         연속 완료 일수.
/// - `quiz_last_done_date` 마지막 완료 'YYYYMMDD'(스트릭 day-diff 기준).
abstract class QuizLocalDataSource {
  /// 개인 순열 시드. 없으면 즉시 생성·저장 후 반환(최초 실행 1회).
  Future<int> getOrCreateSeed();

  /// 현재 진행 커서(0..total). 미설정 시 0.
  Future<int> getCursor();

  /// 오늘([dateKey]) 세트 완료 여부.
  Future<bool> isDoneToday(String dateKey);

  /// 현재 스트릭(연속 완료 일수). 미설정 시 0.
  Future<int> getStreak();

  /// 마지막 완료 날짜 키. 없으면 null.
  Future<String?> getLastDoneDate();

  /// 세트 완료 1회 커밋(원자적): 완료한 [solvedCount] 만큼 커서 전진(완주 시
  /// 재셔플+0), 오늘 done 기록, 스트릭 day-diff 갱신, 과거 done 키 정리.
  ///
  /// 이미 오늘 완료 상태면 멱등 처리(스트릭 중복 증가 금지). 반환 = 갱신된 스트릭.
  /// 커서 전진/재셔플은 호출부가 넘긴 [advanceCursor] 콜백에 위임(순열 로직 분리).
  Future<int> commitSetCompletion({
    required String dateKey,
    required int solvedCount,
    required Future<void> Function(int solvedCount) advanceCursor,
  });

  /// 과거 `quiz_done_*` 키 정리(오늘 [todayKey] 로 끝나는 키는 보존).
  /// 반환 = 삭제한 키 수.
  Future<int> purgePastDoneKeys(String todayKey);

  /// 커서를 [value] 로 설정(재셔플 로직에서 사용).
  Future<void> setCursor(int value);

  /// 시드를 [value] 로 설정(재셔플 로직에서 사용).
  Future<void> setSeed(int value);
}

class QuizLocalDataSourceImpl implements QuizLocalDataSource {
  final SharedPreferences prefs;

  /// 테스트에서 시드 생성을 결정적으로 만들기 위한 주입구(미지정 시 보안 난수).
  final int Function()? seedFactory;

  QuizLocalDataSourceImpl({required this.prefs, this.seedFactory});

  static const String _kSeed = 'quiz_seed';
  static const String _kCursor = 'quiz_cursor';
  static const String _kStreak = 'quiz_streak';
  static const String _kLastDone = 'quiz_last_done_date';
  static const String _kDonePrefix = 'quiz_done_';

  String _doneKey(String dateKey) => '$_kDonePrefix$dateKey';

  @override
  Future<int> getOrCreateSeed() async {
    final existing = prefs.getInt(_kSeed);
    if (existing != null) return existing;
    final seed = (seedFactory ?? _randomSeed)();
    await prefs.setInt(_kSeed, seed);
    return seed;
  }

  /// 1..2^31-1 범위 보안 난수(0 회피 — 시드 0도 동작하지만 "미설정" 과 헷갈림 방지).
  int _randomSeed() => Random.secure().nextInt(0x7FFFFFFF) + 1;

  @override
  Future<int> getCursor() async => prefs.getInt(_kCursor) ?? 0;

  @override
  Future<void> setCursor(int value) async => prefs.setInt(_kCursor, value);

  @override
  Future<void> setSeed(int value) async => prefs.setInt(_kSeed, value);

  @override
  Future<bool> isDoneToday(String dateKey) async =>
      prefs.getBool(_doneKey(dateKey)) ?? false;

  @override
  Future<int> getStreak() async => prefs.getInt(_kStreak) ?? 0;

  @override
  Future<String?> getLastDoneDate() async => prefs.getString(_kLastDone);

  @override
  Future<int> commitSetCompletion({
    required String dateKey,
    required int solvedCount,
    required Future<void> Function(int solvedCount) advanceCursor,
  }) async {
    // 멱등: 오늘 이미 완료면 커서·스트릭 재반영 금지(중복 증가 방지).
    if (await isDoneToday(dateKey)) {
      return getStreak();
    }

    // 1) 커서 전진(완주 시 재셔플+0) — 순열 로직은 콜백에 위임.
    await advanceCursor(solvedCount);

    // 2) 스트릭 day-diff 갱신.
    final last = prefs.getString(_kLastDone);
    int streak = prefs.getInt(_kStreak) ?? 0;
    if (last == null) {
      streak = 1;
    } else {
      final diff = quizDayDiff(last, dateKey);
      if (diff == null) {
        streak = 1; // 파싱 불가(이상 데이터) → 안전하게 리셋.
      } else if (diff <= 0) {
        // 0=오늘 이미(멱등 위에서 차단됐어야 함), 음수=시계 역행 → 유지.
        if (streak < 1) streak = 1;
      } else if (diff == 1) {
        streak += 1;
      } else {
        streak = 1; // 2일 이상 공백 → 리셋.
      }
    }
    await prefs.setInt(_kStreak, streak);
    await prefs.setString(_kLastDone, dateKey);

    // 3) 오늘 done 기록 + 과거 done 키 정리.
    await prefs.setBool(_doneKey(dateKey), true);
    await purgePastDoneKeys(dateKey);

    return streak;
  }

  @override
  Future<int> purgePastDoneKeys(String todayKey) async {
    final todayDone = _doneKey(todayKey);
    final stale = prefs
        .getKeys()
        .where((k) => k.startsWith(_kDonePrefix) && k != todayDone)
        .toList();
    for (final k in stale) {
      await prefs.remove(k);
    }
    return stale.length;
  }
}
