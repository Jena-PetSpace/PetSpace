import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/config/injection_container.dart' show sl;
import 'package:meong_nyang_diary/features/quiz/data/datasources/quiz_local_data_source.dart';
import 'package:meong_nyang_diary/features/quiz/presentation/widgets/home_quiz_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 위젯 수명 동안 고정되는 오늘 키와 동일하게 맞추기 위해 실제 today 사용.
  String today() => quizDateKey();

  Future<void> registerSl(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final p = await SharedPreferences.getInstance();
    await sl.reset();
    sl.registerLazySingleton<SharedPreferences>(() => p);
    sl.registerLazySingleton<QuizLocalDataSource>(
        () => QuizLocalDataSourceImpl(prefs: p, seedFactory: () => 12345));
  }

  tearDown(() async => sl.reset());

  // 라우팅 검증용 — 탭 시 이동 경로를 기록.
  String? lastRoute;
  GoRouter router() => GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
              path: '/home',
              builder: (_, __) => const Scaffold(body: HomeQuizCard())),
          GoRoute(
              path: '/quiz/play',
              builder: (_, s) {
                lastRoute = '/quiz/play';
                return const Scaffold(body: Text('PLAY'));
              }),
          GoRoute(
              path: '/quiz/result',
              builder: (_, s) {
                lastRoute = '/quiz/result?${s.uri.query}';
                return const Scaffold(body: Text('RESULT'));
              }),
        ],
      );

  Widget app() => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp.router(routerConfig: router()),
      );

  Future<void> pump(WidgetTester tester) async {
    lastRoute = null;
    await tester.pumpWidget(app());
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('미완료 분기', () {
    testWidgets('CTA + "풀기" 노출, 스트릭 0이면 🔥 숨김', (tester) async {
      await registerSl({'quiz_streak': 0});
      await pump(tester);

      expect(find.text('오늘의 O/X 퀴즈'), findsOneWidget);
      expect(find.text('풀기'), findsOneWidget);
      expect(find.textContaining('🔥'), findsNothing); // 스트릭 0 → 배지 숨김
    });

    testWidgets('스트릭>0 이면 🔥 배지 노출', (tester) async {
      await registerSl({'quiz_streak': 3});
      await pump(tester);
      expect(find.textContaining('🔥 3일'), findsOneWidget);
    });

    testWidgets('탭 → /quiz/play 이동', (tester) async {
      await registerSl({'quiz_streak': 0});
      await pump(tester);
      await tester.tap(find.text('오늘의 O/X 퀴즈'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(lastRoute, '/quiz/play');
    });
  });

  group('완료 분기', () {
    Map<String, Object> doneState(int correct, int total, int streak) {
      final t = today();
      return {
        'quiz_done_$t': true,
        'quiz_streak': streak,
        'quiz_today_result_$t': jsonEncode({
          'dateKey': t,
          'correctCount': correct,
          'total': total,
          'answers': [],
        }),
      };
    }

    testWidgets('완료 카드 — "오늘 퀴즈 완료!" + 정답 수 + 스트릭', (tester) async {
      await registerSl(doneState(3, 4, 5));
      await pump(tester);

      expect(find.text('오늘 퀴즈 완료!'), findsOneWidget);
      expect(find.textContaining('4문제 중 3개 정답'), findsOneWidget);
      expect(find.textContaining('🔥 5일'), findsOneWidget);
      expect(find.text('풀기'), findsNothing); // CTA 아님
    });

    testWidgets('완료 카드 탭 → /quiz/result(스냅샷 복기, dateKey 전달)', (tester) async {
      await registerSl(doneState(2, 4, 1));
      await pump(tester);
      await tester.tap(find.text('오늘 퀴즈 완료!'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(lastRoute, contains('/quiz/result'));
      expect(lastRoute, contains('dateKey=${today()}'));
    });
  });
}
