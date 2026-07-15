import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';
import 'package:meong_nyang_diary/features/pets/presentation/pages/pet_detail_page.dart';
import 'package:meong_nyang_diary/features/pets/presentation/pages/pet_editor_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

class _FakePetEvent extends Fake implements PetEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPetBloc petBloc;
  late Pet pet;

  setUpAll(() {
    registerFallbackValue(_FakePetEvent());
  });

  setUp(() {
    pet = Pet(
      id: 'pet-1',
      userId: 'user-1',
      name: '아주아주긴반려동물이름흰둥이',
      type: PetType.dog,
      breed: '아주 긴 품종 이름이 들어가는 혼합견',
      gender: PetGender.male,
      birthDate: DateTime(2024, 1, 1),
      description: '산책과 공놀이를 좋아해요.',
      createdAt: DateTime(2026, 1, 6),
      updatedAt: DateTime(2026, 1, 7),
    );
    petBloc = _MockPetBloc();
    when(() => petBloc.state)
        .thenReturn(PetLoaded(pets: [pet], selectedPet: pet));
    whenListen(
      petBloc,
      const Stream<PetState>.empty(),
      initialState: PetLoaded(pets: [pet], selectedPet: pet),
    );
  });

  tearDown(() async {
    await petBloc.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    double textScale = 1,
    Size surface = const Size(390, 844),
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<PetBloc>.value(
            value: petBloc,
            child: PetDetailPage(pet: pet),
          ),
        ),
        GoRoute(
          path: PetEditorRoutes.editPath,
          name: PetEditorRoutes.editName,
          builder: (_, __) => const Scaffold(body: Text('EDIT_PAGE')),
        ),
        GoRoute(
          path: '/emotion',
          builder: (_, __) => const Scaffold(body: Text('EMOTION_PAGE')),
        ),
        GoRoute(
          path: '/create-post',
          builder: (_, __) => const Scaffold(body: Text('CREATE_POST_PAGE')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact identity와 정확한 등록일을 360x800·150%에서 표시한다', (tester) async {
    await pumpPage(
      tester,
      surface: const Size(360, 800),
      textScale: 1.5,
    );

    expect(find.byKey(const Key('pet_detail_identity')), findsOneWidget);
    expect(find.text('등록한 날'), findsOneWidget);
    expect(find.text('2026.01.06'), findsOneWidget);
    expect(find.text('함께한 날'), findsNothing);
    expect(find.byKey(const Key('pet_detail_avatar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('정보 수정·AI 분석·게시물 작성 동선을 모두 유지한다', (tester) async {
    await pumpPage(tester);

    await tester.ensureVisible(find.byKey(const Key('pet_detail_edit_button')));
    await tester.tap(find.byKey(const Key('pet_detail_edit_button')));
    await tester.pumpAndSettle();
    expect(find.text('EDIT_PAGE'), findsOneWidget);

    GoRouter.of(tester.element(find.text('EDIT_PAGE'))).pop();
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const Key('pet_detail_emotion_button')));
    await tester.tap(find.byKey(const Key('pet_detail_emotion_button')));
    await tester.pumpAndSettle();
    expect(find.text('EMOTION_PAGE'), findsOneWidget);

    GoRouter.of(tester.element(find.text('EMOTION_PAGE'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('pet_detail_create_post_button')),
    );
    await tester.tap(find.byKey(const Key('pet_detail_create_post_button')));
    await tester.pumpAndSettle();
    expect(find.text('CREATE_POST_PAGE'), findsOneWidget);
  });

  testWidgets('삭제 확인은 검증되지 않은 cascade를 약속하지 않고 event를 보낸다', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('pet_detail_overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.textContaining('복구할 수 없습니다'), findsOneWidget);
    expect(find.textContaining('관련된 모든 데이터'), findsNothing);
    await tester.tap(find.byKey(const Key('pet_detail_delete_confirm')));
    await tester.pumpAndSettle();

    verify(
      () => petBloc.add(any(that: isA<DeletePetEvent>())),
    ).called(1);
  });
}
