import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/features/quiz/data/datasources/quiz_content_data_source.dart';
import 'package:meong_nyang_diary/features/quiz/data/datasources/quiz_local_data_source.dart';
import 'package:meong_nyang_diary/features/quiz/domain/entities/quiz_result_snapshot.dart';
import 'package:meong_nyang_diary/features/quiz/domain/services/quiz_session_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // 결정적 시드(테스트 안정성).
  QuizLocalDataSourceImpl makeStore({int seed = 12345}) =>
      QuizLocalDataSourceImpl(prefs: prefs, seedFactory: () => seed);

  group('quizDateKey — 로컬 자정 경계', () {
    test('YYYYMMDD 0패딩', () {
      expect(quizDateKey(DateTime(2026, 6, 4)), '20260604');
      expect(quizDateKey(DateTime(2026, 1, 9)), '20260109');
    });

    test('자정 직전/직후 키 변화', () {
      expect(quizDateKey(DateTime(2026, 6, 4, 23, 59)), '20260604');
      expect(quizDateKey(DateTime(2026, 6, 5, 0, 1)), '20260605');
    });
  });

  group('quizDayDiff — 날짜 차이(문자열 비교 아님)', () {
    test('하루 차이=1', () {
      expect(quizDayDiff('20260604', '20260605'), 1);
    });
    test('월 경계 안전', () {
      expect(quizDayDiff('20260131', '20260201'), 1);
      expect(quizDayDiff('20260228', '20260301'), 1); // 2026 비윤년
    });
    test('연 경계 안전', () {
      expect(quizDayDiff('20251231', '20260101'), 1);
    });
    test('역행은 음수', () {
      expect(quizDayDiff('20260605', '20260604'), -1);
    });
    test('형식 오류는 null', () {
      expect(quizDayDiff('bad', '20260604'), isNull);
    });
  });

  group('getOrCreateSeed — 최초 1회 생성·고정', () {
    test('없으면 생성·저장, 이후 동일', () async {
      final store = makeStore(seed: 7777);
      final a = await store.getOrCreateSeed();
      final b = await store.getOrCreateSeed();
      expect(a, 7777);
      expect(b, 7777);
      expect(prefs.getInt('quiz_seed'), 7777);
    });

    test('이미 있으면 factory 무시', () async {
      await prefs.setInt('quiz_seed', 42);
      final store = makeStore(seed: 9999);
      expect(await store.getOrCreateSeed(), 42);
    });
  });

  group('커서 기본값/설정', () {
    test('미설정 시 0', () async {
      expect(await makeStore().getCursor(), 0);
    });
    test('setCursor 반영', () async {
      final store = makeStore();
      await store.setCursor(8);
      expect(await store.getCursor(), 8);
    });
  });

  group('스트릭 day-diff (직접 검증)', () {
    Future<int> commit(QuizLocalDataSourceImpl store, String date,
        {int solved = 4}) {
      // 커서 전진은 별도 검증하므로 여기선 no-op advance.
      return store.commitSetCompletion(
        dateKey: date,
        solvedCount: solved,
        advanceCursor: (_) async {},
      );
    }

    test('첫 완료 → streak=1', () async {
      final store = makeStore();
      expect(await commit(store, '20260604'), 1);
      expect(prefs.getString('quiz_last_done_date'), '20260604');
    });

    test('연속일 → +1', () async {
      final store = makeStore();
      await commit(store, '20260604');
      expect(await commit(store, '20260605'), 2);
      expect(await commit(store, '20260606'), 3);
    });

    test('하루 건너뜀(2일 차) → 리셋 1', () async {
      final store = makeStore();
      await commit(store, '20260604');
      await commit(store, '20260605'); // streak 2
      expect(await commit(store, '20260607'), 1); // 2일 공백
    });

    test('같은 날 재호출 → 멱등(증가 없음)', () async {
      final store = makeStore();
      expect(await commit(store, '20260604'), 1);
      expect(await commit(store, '20260604'), 1); // done 이라 멱등
      expect(prefs.getInt('quiz_streak'), 1);
    });
  });

  group('done 게이팅 + 멱등 커서', () {
    test('완료 전 false, 완료 후 true', () async {
      final store = makeStore();
      expect(await store.isDoneToday('20260604'), isFalse);
      await store.commitSetCompletion(
        dateKey: '20260604',
        solvedCount: 4,
        advanceCursor: (_) async => store.setCursor(4),
      );
      expect(await store.isDoneToday('20260604'), isTrue);
      expect(await store.getCursor(), 4);
    });

    test('오늘 이미 완료면 advanceCursor 미호출(커서 불변)', () async {
      final store = makeStore();
      await store.setCursor(4);
      await prefs.setBool('quiz_done_20260604', true); // 이미 완료 상태
      var advanceCalled = false;
      await store.commitSetCompletion(
        dateKey: '20260604',
        solvedCount: 4,
        advanceCursor: (_) async => advanceCalled = true,
      );
      expect(advanceCalled, isFalse);
      expect(await store.getCursor(), 4); // 전진 안 함
    });
  });

  group('purgePastDoneKeys — 과거 done 정리, 오늘 보존', () {
    test('과거 done 만 삭제', () async {
      final store = makeStore();
      await prefs.setBool('quiz_done_20260601', true);
      await prefs.setBool('quiz_done_20260603', true);
      await prefs.setBool('quiz_done_20260604', true); // 오늘
      final removed = await store.purgePastDoneKeys('20260604');
      expect(removed, 2);
      expect(prefs.getBool('quiz_done_20260604'), isTrue);
      expect(prefs.containsKey('quiz_done_20260601'), isFalse);
    });

    test('quiz_done_ 외 키는 건드리지 않음', () async {
      final store = makeStore();
      await prefs.setInt('quiz_seed', 1);
      await prefs.setInt('quiz_cursor', 8);
      await prefs.setInt('quiz_streak', 3);
      await prefs.setBool('quiz_done_20260601', true); // 과거
      await store.purgePastDoneKeys('20260604');
      expect(prefs.getInt('quiz_seed'), 1);
      expect(prefs.getInt('quiz_cursor'), 8);
      expect(prefs.getInt('quiz_streak'), 3);
    });
  });

  group('QuizSessionBuilder — 통합(콘텐츠+상태)', () {
    late QuizSessionBuilder builder;
    late QuizLocalDataSourceImpl store;

    setUp(() {
      store = makeStore(seed: 314159);
      builder = QuizSessionBuilder(
        contentDataSource: QuizContentDataSourceImpl(),
        localDataSource: store,
      );
    });

    test('오늘 세트 = 커서 위치 4문항, 재진입해도 동일(커밋 전)', () async {
      final a = await builder.buildTodaySet();
      final b = await builder.buildTodaySet();
      expect(a.questions.length, 4);
      expect(a, b); // 커밋 전이므로 같은 세트
      expect(a.cursor, 0);
    });

    test('세트 완료 → 커서 +4, 다음 세트는 다른 문항', () async {
      final first = await builder.buildTodaySet();
      await builder.commitCompletion(dateKey: '20260604', solvedCount: 4);
      expect(await store.getCursor(), 4);

      // 다음 날 새 세트(자정 후) — done 게이팅은 호출부 책임이므로 빌더는 커서로만 진행.
      final second = await builder.buildTodaySet();
      expect(second.cursor, 4);
      final firstIds = first.questions.map((q) => q.id).toSet();
      final secondIds = second.questions.map((q) => q.id).toSet();
      expect(firstIds.intersection(secondIds), isEmpty); // 무중복
    });

    test('완주(커서 266→잔여 4 미만) 시 재셔플+커서 0', () async {
      // 커서를 마지막 잔여 세트 직전으로 밀어 완주 트리거.
      await store.setCursor(268); // 잔여 2문항
      final set = await builder.buildTodaySet();
      expect(set.questions.length, 2); // 잔여 세트

      final seedBefore = prefs.getInt('quiz_seed');
      await builder.commitCompletion(dateKey: '20260604', solvedCount: 2);

      // 270 도달 → 재셔플(새 시드) + 커서 0.
      expect(await store.getCursor(), 0);
      expect(prefs.getInt('quiz_seed'), isNot(seedBefore));
    });
  });

  group('결과 스냅샷 — 저장/조회/정리', () {
    QuizResultSnapshot sample(String date) => QuizResultSnapshot(
          dateKey: date,
          correctCount: 3,
          total: 4,
          answers: const [
            QuizAnswerSnapshot(
                qId: 'behavior_01',
                statement: '진술1',
                chosen: 'O',
                answer: 'O',
                explain: '해설1'),
            QuizAnswerSnapshot(
                qId: 'behavior_03',
                statement: '진술2',
                chosen: 'O',
                answer: 'X',
                explain: '해설2'),
          ],
        );

    test('저장 후 조회 — 라운드트립 동등', () async {
      final store = makeStore();
      await store.saveResultSnapshot(sample('20260604'));
      final loaded = await store.getResultSnapshot('20260604');
      expect(loaded, sample('20260604')); // Equatable 전체 동등
      expect(loaded!.answers.first.isCorrect, isTrue);
      expect(loaded.answers[1].isCorrect, isFalse);
    });

    test('없으면 null', () async {
      expect(await makeStore().getResultSnapshot('20260604'), isNull);
    });

    test('손상된 JSON → null(폴백)', () async {
      await prefs.setString('quiz_today_result_20260604', '{not json');
      expect(await makeStore().getResultSnapshot('20260604'), isNull);
    });

    test('purge 가 과거 result 스냅샷도 정리(오늘 보존)', () async {
      final store = makeStore();
      await store.saveResultSnapshot(sample('20260601')); // 과거
      await store.saveResultSnapshot(sample('20260604')); // 오늘
      await prefs.setBool('quiz_done_20260602', true); // 과거 done

      final removed = await store.purgePastDoneKeys('20260604');
      // 과거 result 1 + 과거 done 1 = 2 삭제.
      expect(removed, 2);
      expect(await store.getResultSnapshot('20260604'), isNotNull); // 오늘 보존
      expect(await store.getResultSnapshot('20260601'), isNull); // 과거 삭제
    });
  });
}
