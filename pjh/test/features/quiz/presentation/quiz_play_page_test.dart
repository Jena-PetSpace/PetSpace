import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/config/injection_container.dart' show sl;
import 'package:meong_nyang_diary/features/quiz/data/datasources/quiz_content_data_source.dart';
import 'package:meong_nyang_diary/features/quiz/data/datasources/quiz_local_data_source.dart';
import 'package:meong_nyang_diary/features/quiz/domain/services/quiz_session_builder.dart';
import 'package:meong_nyang_diary/features/quiz/presentation/pages/quiz_play_page.dart';
import 'package:meong_nyang_diary/features/quiz/presentation/widgets/quiz_feedback_banner.dart';
import 'package:meong_nyang_diary/features/quiz/presentation/widgets/quiz_ox_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'quiz_seed': 12345, 'quiz_cursor': 0});
    final prefs = await SharedPreferences.getInstance();

    await sl.reset();
    sl.registerLazySingleton<SharedPreferences>(() => prefs);
    sl.registerLazySingleton<QuizContentDataSource>(
        () => QuizContentDataSourceImpl());
    sl.registerLazySingleton<QuizLocalDataSource>(
        () => QuizLocalDataSourceImpl(prefs: prefs, seedFactory: () => 12345));
    sl.registerLazySingleton(() => QuizSessionBuilder(
          contentDataSource: sl(),
          localDataSource: sl(),
        ));

    // 콘텐츠 캐시 워밍: rootBundle 비동기 로드가 pump 중 안 끝나는 문제를 피하려
    // 싱글톤 캐시를 미리 채운다(이후 FutureBuilder 는 캐시에서 즉시 해소).
    await sl<QuizContentDataSource>().loadContent();
  });

  tearDown(() async => sl.reset());

  Widget wrap() => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => const MaterialApp(home: QuizPlayPage()),
      );

  // CircularProgressIndicator 가 무한 애니메이션이라 pumpAndSettle 은 타임아웃.
  // rootBundle 비동기 콘텐츠 로드가 끝날 때까지(=로딩 인디케이터 사라질 때까지)
  // 짧게 반복 pump 한다.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('초기: 진행 1/4, O·X 버튼 노출, [다음] 비활성(안내 문구)', (tester) async {
    await pump(tester);

    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.byType(QuizOxButton), findsNWidgets(2));
    // 답 선택 전엔 해설 배너 없음, 하단은 안내 문구.
    expect(find.byType(QuizFeedbackBanner), findsNothing);
    expect(find.text('O 또는 X를 선택하세요'), findsOneWidget);
  });

  testWidgets('O/X 선택 → 즉시 정오+해설 배너 등장 → [다음] 활성', (tester) async {
    await pump(tester);

    await tester.tap(find.descendant(
        of: find.byType(QuizOxButton), matching: find.text('O')));
    await settle(tester);

    // 정오/해설 배너 등장(정답 또는 오답 텍스트 중 하나가 보임).
    expect(find.byType(QuizFeedbackBanner), findsOneWidget);
    final hasVerdict = find.text('정답').evaluate().isNotEmpty ||
        find.text('오답').evaluate().isNotEmpty;
    expect(hasVerdict, isTrue);

    // [다음] 활성화.
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('O 또는 X를 선택하세요'), findsNothing);
  });

  testWidgets('접근성: 정오 피드백이 아이콘+텍스트(색 외 단서) 병기', (tester) async {
    await pump(tester);
    await tester.tap(find.descendant(
        of: find.byType(QuizOxButton), matching: find.text('O')));
    await settle(tester);

    // 배너에 check_circle 또는 cancel 아이콘이 있고, 정답/오답 텍스트가 함께.
    final banner = find.byType(QuizFeedbackBanner);
    final hasIcon = find
            .descendant(of: banner, matching: find.byIcon(Icons.check_circle))
            .evaluate()
            .isNotEmpty ||
        find
            .descendant(of: banner, matching: find.byIcon(Icons.cancel))
            .evaluate()
            .isNotEmpty;
    expect(hasIcon, isTrue);
    final hasText = find
            .descendant(of: banner, matching: find.text('정답'))
            .evaluate()
            .isNotEmpty ||
        find
            .descendant(of: banner, matching: find.text('오답'))
            .evaluate()
            .isNotEmpty;
    expect(hasText, isTrue);
  });

  testWidgets('답변 잠금: 한 번 선택 후 반대 답 탭해도 번복 안 됨', (tester) async {
    await pump(tester);

    // 먼저 O 선택.
    await tester.tap(find.descendant(
        of: find.byType(QuizOxButton), matching: find.text('O')));
    await settle(tester);
    final bannerAfterFirst = find.byType(QuizFeedbackBanner);
    expect(bannerAfterFirst, findsOneWidget);

    // 진행은 여전히 1/4 (자동 이동 금지).
    expect(find.text('1 / 4'), findsOneWidget);

    // 이제 X 를 탭 — 잠금이므로 선택 변경/진행 없음.
    await tester.tap(find.descendant(
        of: find.byType(QuizOxButton), matching: find.text('X')));
    await settle(tester);
    expect(find.text('1 / 4'), findsOneWidget); // 여전히 1번 문항
    expect(find.byType(QuizFeedbackBanner), findsOneWidget); // 배너 1개 유지
  });

  testWidgets('자동 이동 금지: 선택만으로 다음 문항으로 넘어가지 않음', (tester) async {
    await pump(tester);
    await tester.tap(find.descendant(
        of: find.byType(QuizOxButton), matching: find.text('X')));
    await settle(tester);
    // 선택했지만 [다음] 누르기 전엔 1/4 유지.
    expect(find.text('1 / 4'), findsOneWidget);

    // [다음] 탭해야 2/4.
    await tester.tap(find.text('다음'));
    await settle(tester);
    expect(find.text('2 / 4'), findsOneWidget);
  });

  testWidgets('마지막 문항에서는 [결과 보기] 라벨', (tester) async {
    await pump(tester);
    // 1→2→3→4 까지 진행(각 문항 답 후 다음).
    for (var i = 1; i <= 3; i++) {
      await tester.tap(find.descendant(
          of: find.byType(QuizOxButton), matching: find.text('O')));
      await settle(tester);
      await tester.tap(find.text('다음'));
      await settle(tester);
    }
    expect(find.text('4 / 4'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(QuizOxButton), matching: find.text('O')));
    await settle(tester);
    expect(find.text('결과 보기'), findsOneWidget);
  });
}
