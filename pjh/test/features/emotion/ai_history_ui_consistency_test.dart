import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/ai_history.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/analysis_input/analysis_sub_tab.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/history/ai_history_filter_bar.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/history/ai_history_filter_sheet.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/history/ai_history_pet_inline_dropdown.dart';
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
    final secondPet = Pet(
      id: 'pet-2',
      userId: 'user-1',
      name: '두번째견',
      type: PetType.dog,
      breed: '진돗개',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    Pet? selected;

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: PetInlineDropdown(
            pets: [pet, secondPet],
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
    expect(find.byType(Divider), findsNWidgets(3));

    await tester.tap(find.text('테스트견'));
    await tester.pumpAndSettle();
    expect(selected, pet);
  });

  testWidgets('AI 기록 선택기는 하단 시트 없이 같은 영역 안에서 옵션을 펼친다', (tester) async {
    final pet = Pet(
      id: 'pet-1',
      userId: 'user-1',
      name: '테스트견',
      type: PetType.dog,
      breed: '비글',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    AiHistoryPetScope? selected;

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: AiHistoryPetInlineDropdown(
            pets: [pet],
            scope: const AiHistoryPetScope.all(),
            flowMode: false,
            enabled: true,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('전체 기록').first);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('테스트견'), findsOneWidget);
    expect(find.text('연결 안 된 기록'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(3));

    await tester.tap(find.text('테스트견'));
    await tester.pumpAndSettle();
    expect(selected, AiHistoryPetScope.registered(pet.id));
  });

  testWidgets('흐름 선택기는 위에서 고르도록 안내하고 전체·연결 안 된 범위를 숨긴다', (tester) async {
    final pet = Pet(
      id: 'pet-1',
      userId: 'user-1',
      name: '테스트견',
      type: PetType.dog,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: AiHistoryPetInlineDropdown(
            pets: [pet],
            scope: const AiHistoryPetScope.all(),
            flowMode: true,
            enabled: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('반려동물을 선택해주세요'), findsOneWidget);
    await tester.tap(find.text('반려동물을 선택해주세요'));
    await tester.pumpAndSettle();
    expect(find.text('테스트견'), findsOneWidget);
    expect(find.text('전체 기록'), findsNothing);
    expect(find.text('연결 안 된 기록'), findsNothing);
  });

  testWidgets('기록 필터는 한 행에서 현재 조건만 요약한다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: AiHistoryFilterBar(
            type: AiHistoryTypeFilter.health,
            dateRange: AiHistoryDateRange.last90Days,
            healthAttentionOnly: true,
            emotionOnly: false,
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    expect(find.text('기록 필터'), findsOneWidget);
    expect(find.text('건강 · 최근 90일 · 확인 필요'), findsOneWidget);
    expect(find.text('전체 기간'), findsNothing);
    await tester.tap(find.text('기록 필터'));
    expect(taps, 1);
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
