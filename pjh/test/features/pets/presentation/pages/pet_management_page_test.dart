import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';
import 'package:meong_nyang_diary/features/pets/presentation/pages/pet_management_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

class _FakePetEvent extends Fake implements PetEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Pet buildPet(int index) {
    return Pet(
      id: 'pet-$index',
      userId: 'user-1',
      name: index == 3 ? '아주아주긴반려동물이름$index' : '반려동물$index',
      type: index.isEven ? PetType.cat : PetType.dog,
      breed: index == 2 ? null : '비글',
      birthDate: DateTime(2024, index, 1),
      gender: index == 2 ? null : PetGender.male,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );
  }

  setUpAll(() {
    registerFallbackValue(_FakePetEvent());
  });

  Future<_MockPetBloc> pumpPage(
    WidgetTester tester, {
    required PetState state,
    ThemeData? theme,
    Size surface = const Size(390, 844),
    double textScale = 1,
    List<PetState> emittedStates = const [],
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = _MockPetBloc();
    when(() => bloc.state).thenReturn(state);
    whenListen(
      bloc,
      Stream<PetState>.fromIterable(emittedStates),
      initialState: state,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: BlocProvider<PetBloc>.value(
            value: bloc,
            child: const PetManagementPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  void expectFloatingFeedback(
    WidgetTester tester, {
    Color? backgroundColor,
  }) {
    final snackBar = tester.widget<SnackBar>(
      find.byKey(const Key('pet_management_feedback_snackbar')),
    );
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect((snackBar.margin! as EdgeInsets).bottom, greaterThanOrEqualTo(60));
    expect(snackBar.backgroundColor, backgroundColor);
  }

  testWidgets('목록 CTA는 옅은 action container이고 하단 콘텐츠 여유를 확보한다', (tester) async {
    final pet = buildPet(1);
    final bloc = await pumpPage(
      tester,
      state: PetLoaded(pets: [pet], selectedPet: pet),
    );

    verify(() => bloc.add(any(that: isA<LoadUserPets>()))).called(1);
    final addButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('pet_management_add_button')),
    );
    expect(
      addButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppTheme.actionContainer,
    );
    expect(
      tester.getSize(find.byKey(const Key('pet_management_add_button'))).height,
      greaterThanOrEqualTo(48),
    );
    final list = tester.widget<ListView>(
      find.byKey(const Key('pet_management_list')),
    );
    final padding = list.padding! as EdgeInsets;
    expect(padding.bottom, greaterThanOrEqualTo(100));
    expect(
        find.byKey(const Key('pet_card_primary_badge_pet-1')), findsOneWidget);
  });

  testWidgets('여러 카드와 긴 이름을 360x800·150%에서 overflow 없이 표시한다', (tester) async {
    final pets = [buildPet(1), buildPet(2), buildPet(3)];
    await pumpPage(
      tester,
      state: PetLoaded(pets: pets, selectedPet: pets.first),
      surface: const Size(360, 800),
      textScale: 1.5,
    );

    for (final pet in pets) {
      expect(find.byKey(Key('pet_card_${pet.id}')), findsOneWidget);
    }
    expect(find.text('품종 미상'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('대표 설정은 낙관적 성공 안내 없이 이벤트만 전달한다', (tester) async {
    final pet = buildPet(1);
    final bloc = await pumpPage(
      tester,
      state: PetLoaded(pets: [pet]),
    );

    final menu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('pet_card_menu_pet-1')),
    );
    menu.onSelected!('primary');
    await tester.pump();

    verify(() => bloc.add(any(that: isA<SelectPet>()))).called(1);
    expect(find.byKey(const Key('pet_management_feedback_snackbar')),
        findsNothing);
  });

  testWidgets('대표 설정 RPC 성공 뒤에만 floating 성공 안내를 표시한다', (tester) async {
    final pet = buildPet(1);
    await pumpPage(
      tester,
      state: PetLoaded(pets: [pet]),
      emittedStates: [
        PetLoaded(
          pets: [pet],
          selectedPet: pet,
          selectionStatus: PetSelectionStatus.success,
          selectionMessage: '대표 반려동물로 설정했어요: 반려동물1',
        ),
      ],
    );
    await tester.pump();

    expect(find.textContaining('대표 반려동물로 설정했어요'), findsOneWidget);
    expectFloatingFeedback(tester);
  });

  testWidgets('대표 설정 pending은 대상 카드에만 표시한다', (tester) async {
    final pets = [buildPet(1), buildPet(2)];
    await pumpPage(
      tester,
      state: PetLoaded(
        pets: pets,
        selectedPet: pets.first,
        selectionStatus: PetSelectionStatus.pending,
        pendingSelectedPetId: pets.last.id,
      ),
    );

    expect(
      find.byKey(const Key('pet_card_selection_pending_pet-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pet_card_selection_pending_pet-1')),
      findsNothing,
    );
  });

  testWidgets('작업 성공 안내도 같은 floating 여백을 사용한다', (tester) async {
    final pet = buildPet(1);
    await pumpPage(
      tester,
      state: PetLoaded(pets: [pet], selectedPet: pet),
      emittedStates: [
        PetOperationSuccess(message: '저장되었습니다', pets: [pet]),
      ],
    );
    await tester.pump();

    expect(find.text('저장되었습니다'), findsOneWidget);
    expectFloatingFeedback(tester);
  });

  testWidgets('작업 오류 안내는 floating 여백과 오류 색을 유지한다', (tester) async {
    final pet = buildPet(1);
    await pumpPage(
      tester,
      state: PetLoaded(pets: [pet], selectedPet: pet),
      emittedStates: const [PetError('저장에 실패했습니다')],
    );
    await tester.pump();

    expect(find.text('저장에 실패했습니다'), findsWidgets);
    expectFloatingFeedback(tester, backgroundColor: AppTheme.errorColor);
  });

  testWidgets('빈 상태는 공유 상태뷰를 유지하고 populated 전용 CTA를 만들지 않는다', (tester) async {
    await pumpPage(tester, state: const PetLoaded(pets: []));

    expect(find.text('등록된 반려동물이 없습니다'), findsOneWidget);
    expect(find.text('반려동물 추가하기'), findsOneWidget);
    expect(find.byKey(const Key('pet_management_add_button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('삭제 확인은 실제 cascade와 연결 해제 영향을 구분한다', (tester) async {
    final pet = buildPet(1);
    await pumpPage(
      tester,
      state: PetLoaded(pets: [pet], selectedPet: pet),
    );

    final menu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('pet_card_menu_pet-1')),
    );
    menu.onSelected!('delete');
    await tester.pumpAndSettle();

    expect(find.text('함께 삭제되는 정보'), findsOneWidget);
    expect(find.textContaining('건강 기록'), findsOneWidget);
    expect(find.text('기록은 유지되고 연결만 해제'), findsOneWidget);
    expect(find.text('게시물과 산책 기록'), findsOneWidget);
    expect(find.text('이 작업은 되돌릴 수 없습니다.'), findsOneWidget);
  });

  testWidgets('다크모드 CTA는 theme primary container 역할색을 사용한다', (tester) async {
    final pet = buildPet(1);
    await pumpPage(
      tester,
      state: PetLoaded(pets: [pet], selectedPet: pet),
      theme: AppTheme.darkTheme,
    );

    final context = tester.element(
      find.byKey(const Key('pet_management_add_button')),
    );
    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('pet_management_add_button')),
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      Theme.of(context).colorScheme.primaryContainer,
    );
    expect(tester.takeException(), isNull);
  });
}
