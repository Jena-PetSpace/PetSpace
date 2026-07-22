import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';
import 'package:meong_nyang_diary/features/my/presentation/widgets/my_pet_summary_section.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';

class MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

void main() {
  Pet buildPet() => Pet(
        id: 'pet-1',
        userId: 'u-1',
        name: '흰둥이',
        type: PetType.dog,
        breed: '진돗개',
        birthDate: DateTime(2024, 1, 1),
        gender: PetGender.male,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  HealthRecord buildRecord() => HealthRecord(
        id: 'health-1',
        petId: 'pet-1',
        userId: 'u-1',
        recordType: HealthRecordType.vaccination,
        title: '종합 예방접종',
        recordDate: DateTime(2026, 8, 3),
        status: HealthRecordStatus.scheduled,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      );

  Future<MockPetBloc> pumpSection(
    WidgetTester tester, {
    required PetState state,
    LoadMyNextHealth? loadNextHealth,
    double textScale = 1,
  }) async {
    final petBloc = MockPetBloc();
    whenListen(
      petBloc,
      const Stream<PetState>.empty(),
      initialState: state,
    );
    addTearDown(petBloc.close);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<PetBloc>.value(
                value: petBloc,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(390, 844),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: MyPetSummarySection(
                    userId: 'u-1',
                    loadNextHealth: loadNextHealth,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return petBloc;
  }

  testWidgets('펫 0마리는 첫 등록 가치와 CTA를 overflow 없이 표시한다', (tester) async {
    await pumpSection(
      tester,
      state: const PetLoaded(pets: [], selectedPet: null),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('대표 반려동물'), findsOneWidget);
    expect(find.text('첫 반려동물을 등록해보세요'), findsOneWidget);
    expect(find.text('등록하기'), findsOneWidget);
  });

  testWidgets('대표 카드에는 가장 가까운 건강 일정 한 건을 표시한다', (tester) async {
    final pet = buildPet();
    String? requestedUserId;
    String? requestedPetId;
    await pumpSection(
      tester,
      state: PetLoaded(pets: [pet], selectedPet: pet),
      loadNextHealth: ({required userId, required petId}) async {
        requestedUserId = userId;
        requestedPetId = petId;
        return buildRecord();
      },
    );
    await tester.pumpAndSettle();

    expect(requestedUserId, 'u-1');
    expect(requestedPetId, 'pet-1');
    expect(find.byKey(const Key('my_selected_pet_hero')), findsOneWidget);
    expect(find.text('흰둥이'), findsOneWidget);
    expect(find.text('8월 3일 · 종합 예방접종'), findsOneWidget);
  });

  testWidgets('건강 조회 실패는 대표 카드 안에서만 재시도하고 회복한다', (tester) async {
    final pet = buildPet();
    var fail = true;
    await pumpSection(
      tester,
      state: PetLoaded(pets: [pet], selectedPet: pet),
      loadNextHealth: ({required userId, required petId}) async {
        if (fail) throw StateError('private-health-error');
        return buildRecord();
      },
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my_next_health_error')), findsOneWidget);
    expect(find.textContaining('private-health-error'), findsNothing);
    expect(find.text('흰둥이'), findsOneWidget);

    fail = false;
    await tester.tap(find.byKey(const Key('my_next_health_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my_next_health_value')), findsOneWidget);
  });

  testWidgets('여러 마리지만 대표가 없으면 선택 필요 상태를 구분한다', (tester) async {
    final pet = buildPet();
    await pumpSection(
      tester,
      state: PetLoaded(pets: [pet], selectedPet: null),
    );

    expect(find.text('대표 반려동물을 선택해 주세요'), findsOneWidget);
    expect(find.text('선택하기'), findsOneWidget);
    expect(find.byKey(const Key('my_selected_pet_hero')), findsNothing);
  });
}
