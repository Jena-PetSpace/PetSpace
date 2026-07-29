import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/ai_history.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/analysis_input/analysis_sub_tab.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/history/ai_history_filter_sheet.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/pet_inline_dropdown.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';

void main() {
  Widget wrap(Widget child, {EdgeInsets safePadding = EdgeInsets.zero}) {
    return ScreenUtilInit(
      designSize: const Size(360, 800),
      builder: (_, __) => MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          padding: safePadding,
          viewPadding: safePadding,
        ),
        child: MaterialApp(home: child),
      ),
    );
  }

  testWidgets('AI 분석 선택기는 이모지 대신 공용 브랜드 아바타와 메타데이터를 쓴다', (tester) async {
    final pet = Pet(
      id: 'pet-1',
      userId: 'user-1',
      name: '테스트견',
      type: PetType.dog,
      breed: '비글',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    Pet? selected;

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: PetInlineDropdown(
            pets: [pet],
            selectedPet: null,
            showUnregistered: false,
            onPetSelected: (value) => selected = value,
            onUnregisteredChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('🐶'), findsNothing);
    expect(find.byIcon(Icons.pets), findsWidgets);

    await tester.tap(find.text('반려동물을 선택해주세요'));
    await tester.pumpAndSettle();

    expect(find.text('테스트견'), findsOneWidget);
    expect(find.text('강아지 · 비글 · 나이 미상'), findsOneWidget);
    expect(find.text('🐶'), findsNothing);

    await tester.tap(find.text('테스트견'));
    await tester.pumpAndSettle();
    expect(selected, pet);
  });

  testWidgets('기록 필터 적용 버튼은 3버튼 내비게이션 안전영역 위에 배치된다', (tester) async {
    const bottomSafeArea = 48.0;

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => AiHistoryFilterSheet.show(
                  context,
                  initial: const AiHistoryFilterSelection(
                    type: AiHistoryTypeFilter.all,
                    dateRange: AiHistoryDateRange.all,
                    healthAttentionOnly: false,
                  ),
                ),
                child: const Text('필터 열기'),
              ),
            ),
          ),
        ),
        safePadding: const EdgeInsets.only(bottom: bottomSafeArea),
      ),
    );

    await tester.tap(find.text('필터 열기'));
    await tester.pumpAndSettle();

    final applyButton = tester.getRect(
      find.widgetWithText(FilledButton, '적용하기'),
    );
    expect(applyButton.bottom, lessThanOrEqualTo(800 - bottomSafeArea));
    expect(tester.takeException(), isNull);
  });

  testWidgets('분석과 기록의 공용 세그먼트 탭은 선택 상태를 접근성에 노출한다', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Row(
            children: [
              AnalysisSubTab(
                label: '기록',
                index: 0,
                currentIndex: 0,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(AnalysisSubTab));
    final data = semantics.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected.toString(), 'Tristate.isTrue');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    semanticsHandle.dispose();
  });
}
