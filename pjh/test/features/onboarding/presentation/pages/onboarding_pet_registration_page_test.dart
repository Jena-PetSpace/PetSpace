import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPetBloc petBloc;

  setUp(() async {
    await sl.reset();
    petBloc = _MockPetBloc();
    when(() => petBloc.state).thenReturn(PetInitial());
    whenListen(
      petBloc,
      const Stream<PetState>.empty(),
      initialState: PetInitial(),
    );
    sl.registerFactory<PetBloc>(() => petBloc);
  });

  tearDown(() async => sl.reset());

  test('첫 반려동물은 이름·종류만 필수이며 나중에 등록할 수 있다', () {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('skip-first-pet')"));
    expect(source, contains("const Text('나중에')"));
    expect(source, contains("ValueKey('first-pet-name')"));
    expect(source, contains('강아지 또는 고양이를 선택해주세요.'));
    expect(source, contains('생년월일'));
    expect(source, contains('자세한 정보는 MY에서 나중에 추가'));
    expect(source, isNot(contains("labelText: '성별'")));
    expect(source, isNot(contains("labelText: '품종'")));
  });

  testWidgets('320 너비·200% 글자에서 선택 카드와 시작 CTA가 접근 가능한 크기를 유지한다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const OnboardingPetRegistrationPage(),
        ),
      ),
    );
    await tester.pump();

    final dog = find.byKey(const ValueKey('first-pet-type-dog'));
    final cat = find.byKey(const ValueKey('first-pet-type-cat'));
    final submit = find.byKey(const ValueKey('save-first-pet'));
    expect(tester.getSize(dog).height, greaterThanOrEqualTo(84));
    expect(tester.getSize(cat).height, greaterThanOrEqualTo(84));
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    expect(find.text('나중에'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
