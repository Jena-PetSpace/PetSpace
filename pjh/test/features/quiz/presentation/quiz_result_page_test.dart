import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/features/quiz/data/datasources/quiz_content_data_source.dart';
import 'package:meong_nyang_diary/features/quiz/data/datasources/quiz_local_data_source.dart';
import 'package:meong_nyang_diary/features/quiz/domain/services/quiz_reward_hook.dart';
import 'package:meong_nyang_diary/features/quiz/domain/services/quiz_session_builder.dart';

/// 훅 호출 횟수·인자를 기록하는 가짜 보상 훅.
class _SpyRewardHook implements QuizRewardHook {
  int calls = 0;
  int? lastCorrect;
  int? lastTotal;
  int? lastStreak;

  @override
  Future<void> onQuizCompleted({
    required int correctCount,
    required int total,
    required int streak,
  }) async {
    calls++;
    lastCorrect = correctCount;
    lastTotal = total;
    lastStreak = streak;
  }
}

/// 결과 화면이 진입 시 호출하는 커밋 흐름을 그대로 재현하는 헬퍼.
/// (위젯 FutureBuilder 안에서 prefs 쓰기를 await 하면 fake-async pump 로 안 풀려
///  멈추므로, 동일 코드 경로를 순수 async 로 직접 검증한다. UI 렌더는 별도 위젯 테스트.)
Future<int> commitLikePage({
  required QuizLocalDataSource local,
  required QuizSessionBuilder builder,
  required QuizRewardHook hook,
  required int correct,
  required int total,
  required String dateKey,
}) async {
  final alreadyDone = await local.isDoneToday(dateKey);
  if (alreadyDone) {
    return local.getStreak();
  }
  final streak =
      await builder.commitCompletion(dateKey: dateKey, solvedCount: total);
  await hook.onQuizCompleted(
      correctCount: correct, total: total, streak: streak);
  return streak;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _SpyRewardHook hook;
  late QuizLocalDataSourceImpl local;
  late QuizSessionBuilder builder;

  Future<void> register(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    hook = _SpyRewardHook();
    local = QuizLocalDataSourceImpl(prefs: prefs, seedFactory: () => 12345);
    builder = QuizSessionBuilder(
        contentDataSource: QuizContentDataSourceImpl(), localDataSource: local);
    await builder.contentDataSource.loadContent();
  }

  // ── 커밋 흐름(원자성·멱등·스트릭·재셔플·훅) — 순수 async 검증 ──
  group('신규 완주: 원자적 커밋 1회 + 훅 1회', () {
    test('커서 +total, done, 스트릭=1, 훅 1회(인자 전달)', () async {
      await register({'quiz_seed': 12345, 'quiz_cursor': 0});
      final streak = await commitLikePage(
          local: local,
          builder: builder,
          hook: hook,
          correct: 3,
          total: 4,
          dateKey: '20260604');

      expect(prefs.getInt('quiz_cursor'), 4);
      expect(prefs.getBool('quiz_done_20260604'), isTrue);
      expect(prefs.getInt('quiz_streak'), 1);
      expect(streak, 1);
      expect(hook.calls, 1);
      expect(hook.lastCorrect, 3);
      expect(hook.lastTotal, 4);
      expect(hook.lastStreak, 1);
    });
  });

  group('멱등: 같은 날 재진입 — 재커밋·재적립 없음', () {
    test('이미 done 이면 커서·스트릭 불변, 훅 미호출', () async {
      await register({
        'quiz_seed': 12345,
        'quiz_cursor': 4,
        'quiz_done_20260604': true,
        'quiz_streak': 2,
        'quiz_last_done_date': '20260604',
      });
      final streak = await commitLikePage(
          local: local,
          builder: builder,
          hook: hook,
          correct: 2,
          total: 4,
          dateKey: '20260604');

      expect(prefs.getInt('quiz_cursor'), 4);
      expect(prefs.getInt('quiz_streak'), 2);
      expect(streak, 2);
      expect(hook.calls, 0); // 미호출
    });

    test('두 번 연속 호출해도 한 번만 커밋(멱등)', () async {
      await register({'quiz_seed': 12345, 'quiz_cursor': 0});
      await commitLikePage(
          local: local,
          builder: builder,
          hook: hook,
          correct: 4,
          total: 4,
          dateKey: '20260604');
      await commitLikePage(
          local: local,
          builder: builder,
          hook: hook,
          correct: 4,
          total: 4,
          dateKey: '20260604'); // 재진입

      expect(prefs.getInt('quiz_cursor'), 4); // 8 아님
      expect(prefs.getInt('quiz_streak'), 1); // 2 아님
      expect(hook.calls, 1); // 1회만
    });
  });

  group('스트릭 day-diff: 결과 시점 발동', () {
    test('어제 완료 → 오늘 +1', () async {
      await register({
        'quiz_seed': 12345,
        'quiz_cursor': 8,
        'quiz_streak': 3,
        'quiz_last_done_date': '20260603',
      });
      final streak = await commitLikePage(
          local: local,
          builder: builder,
          hook: hook,
          correct: 4,
          total: 4,
          dateKey: '20260604');
      expect(streak, 4);
    });

    test('이틀 공백 → 리셋 1', () async {
      await register({
        'quiz_seed': 12345,
        'quiz_cursor': 8,
        'quiz_streak': 5,
        'quiz_last_done_date': '20260601',
      });
      final streak = await commitLikePage(
          local: local,
          builder: builder,
          hook: hook,
          correct: 1,
          total: 4,
          dateKey: '20260604');
      expect(streak, 1);
    });
  });

  group('완주 재셔플 경계: cursor 270 도달', () {
    test('마지막 잔여 세트(2문항) 완료 → 재셔플(새 시드)+커서 0', () async {
      await register({
        'quiz_seed': 12345,
        'quiz_cursor': 268, // 잔여 2
        'quiz_last_done_date': '20260603',
        'quiz_streak': 1,
      });
      await commitLikePage(
          local: local,
          builder: builder,
          hook: hook,
          correct: 2,
          total: 2, // 잔여 세트 크기
          dateKey: '20260604');

      expect(prefs.getInt('quiz_cursor'), 0);
      expect(prefs.getInt('quiz_seed'), isNot(12345));
      expect(prefs.getBool('quiz_done_20260604'), isTrue);
      expect(hook.calls, 1);
    });
  });

  // 참고: 결과 화면 UI 렌더(N/total·🔥·면책)는 골든 캡처로 검증한다.
  // (위젯 FutureBuilder + mock prefs 조합이 fake-async pump 에서 안정적으로
  //  해소되지 않아, 위젯 테스트 대신 정적 골든 + 위 커밋 흐름 테스트로 분담.)
}
