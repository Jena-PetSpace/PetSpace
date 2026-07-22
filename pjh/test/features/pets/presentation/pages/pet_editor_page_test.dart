import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/services/image_upload_service.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/add_pet.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/delete_pet.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/get_user_pets.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/get_selected_pet_id.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/set_selected_pet_id.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/update_pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';
import 'package:meong_nyang_diary/features/pets/presentation/pages/pet_editor_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

class _FakePetEvent extends Fake implements PetEvent {}

class _MockGetUserPets extends Mock implements GetUserPets {}

class _MockAddPet extends Mock implements AddPet {}

class _MockUpdatePet extends Mock implements UpdatePet {}

class _MockDeletePet extends Mock implements DeletePet {}

class _MockGetSelectedPetId extends Mock implements GetSelectedPetId {}

class _MockSetSelectedPetId extends Mock implements SetSelectedPetId {}

class _MockImageUploadService extends Mock implements ImageUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Pet buildPet() {
    return Pet(
      id: 'pet-1',
      userId: 'user-1',
      name: '몽이',
      type: PetType.dog,
      breed: '테스트 믹스',
      birthDate: DateTime(2023, 4, 12),
      gender: PetGender.male,
      avatarUrl: 'https://example.com/pet.jpg',
      description: '산책을 좋아해요',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      currentMbtiType: 'ENFP',
      currentMbtiUpdatedAt: DateTime(2026, 2, 1),
      passportNo: 'PKR12345',
      passportSurname: 'KIM',
      passportGivenName: 'MONGE',
      nameHanguel: '몽이',
      countryCode: 'KOR',
    );
  }

  setUpAll(() {
    registerFallbackValue(_FakePetEvent());
    registerFallbackValue(buildPet());
  });

  Future<_MockPetBloc> pumpEditor(
    WidgetTester tester, {
    Pet? pet,
    StreamController<PetState>? stateController,
    PetState? initialState,
    ThemeData? theme,
    Size surface = const Size(390, 844),
    double textScale = 1,
    double keyboardInset = 0,
    Future<File?> Function(BuildContext context)? imagePicker,
    ImageUploadService? imageUploadService,
    Widget Function(File imageFile)? selectedImageBuilder,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = _MockPetBloc();
    final loaded = PetLoaded(
      pets: pet == null ? const [] : [pet],
      selectedPet: pet,
    );
    final initial = initialState ?? loaded;
    when(() => bloc.state).thenReturn(initial);
    whenListen(
      bloc,
      stateController?.stream ?? const Stream<PetState>.empty(),
      initialState: initial,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: theme,
          initialRoute: '/editor',
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: child!,
          ),
          routes: {
            '/': (_) => const Scaffold(body: Center(child: Text('기준 화면'))),
            '/editor': (_) => BlocProvider<PetBloc>.value(
                  value: bloc,
                  child: PetEditorPage(
                    userId: 'user-1',
                    pet: pet,
                    imagePicker: imagePicker,
                    imageUploadService: imageUploadService,
                    selectedImageBuilder: selectedImageBuilder,
                  ),
                ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  Future<void> goToStepTwo(WidgetTester tester, {String name = '초코'}) async {
    await tester.enterText(
        find.byKey(const Key('pet_editor_name_field')), name);
    await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
    await tester.pumpAndSettle();
  }

  group('PetBloc 성공 상태 계약', () {
    late _MockGetUserPets getUserPets;
    late _MockAddPet addPet;
    late _MockUpdatePet updatePet;
    late _MockDeletePet deletePet;
    late _MockGetSelectedPetId getSelectedPetId;
    late _MockSetSelectedPetId setSelectedPetId;

    setUp(() {
      getUserPets = _MockGetUserPets();
      addPet = _MockAddPet();
      updatePet = _MockUpdatePet();
      deletePet = _MockDeletePet();
      getSelectedPetId = _MockGetSelectedPetId();
      setSelectedPetId = _MockSetSelectedPetId();
      when(() => setSelectedPetId(any())).thenAnswer((invocation) async =>
          Right(invocation.positionalArguments.first as String?));
    });

    blocTest<PetBloc, PetState>(
      '등록 성공은 transient success 뒤 최종 PetLoaded로 돌아간다',
      setUp: () {
        when(() => addPet(any())).thenAnswer((invocation) async {
          return Right(invocation.positionalArguments.first as Pet);
        });
      },
      build: () => PetBloc(
        getUserPets: getUserPets,
        addPet: addPet,
        updatePet: updatePet,
        deletePet: deletePet,
        getSelectedPetId: getSelectedPetId,
        setSelectedPetId: setSelectedPetId,
      ),
      seed: () => const PetLoaded(pets: []),
      act: (bloc) => bloc.add(AddPetEvent(buildPet())),
      expect: () => [
        isA<PetLoading>(),
        isA<PetOperationSuccess>(),
        isA<PetLoaded>().having((state) => state.pets.length, 'pet count', 1),
      ],
    );
  });

  group('PetEditorPage B안', () {
    testWidgets('등록 1단계 검증 뒤 선택 정보 2단계로 이동한다', (tester) async {
      await pumpEditor(tester);

      expect(find.text('반려동물 등록'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('사진 추가'), findsOneWidget);
      expect(find.text('기본 정보'), findsOneWidget);
      expect(find.text('먼저 꼭 필요한 것만 알려주세요'), findsOneWidget);
      expect(find.text('이름 *'), findsOneWidget);
      expect(find.text('강아지'), findsOneWidget);
      expect(find.text('고양이'), findsOneWidget);
      expect(find.text('다음'), findsOneWidget);
      expect(find.text('품종'), findsNothing);
      expect(find.text('여권 정보'), findsNothing);

      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();
      expect(find.text('이름을 입력해주세요'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      await goToStepTwo(tester);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('추가 정보'), findsOneWidget);
      expect(find.text('건너뛰기'), findsOneWidget);
      expect(find.text('등록 완료'), findsOneWidget);
      expect(
        find.text('여권 정보는 등록 완료 후 반려동물 상세에서 만들 수 있어요.'),
        findsOneWidget,
      );
      expect(find.text('영문 성 (Surname)'), findsNothing);
    });

    testWidgets('건너뛰기는 선택값을 지우지 않고 AddPetEvent를 한 번 보낸다', (tester) async {
      final bloc = await pumpEditor(tester);
      await goToStepTwo(tester, name: '초코');
      await tester.tap(find.text('암컷'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pet_editor_skip_button')));
      await tester.pump();

      final event = verify(
        () => bloc.add(captureAny(that: isA<AddPetEvent>())),
      ).captured.single as AddPetEvent;
      expect(event.pet.userId, 'user-1');
      expect(event.pet.name, '초코');
      expect(event.pet.type, PetType.dog);
      expect(event.pet.gender, PetGender.female);
      expect(event.pet.breed, isNull);
      expect(event.pet.passportSurname, isNull);
      expect(event.pet.countryCode, 'KOR');
    });

    testWidgets('등록 완료는 입력한 선택 정보를 AddPetEvent에 매핑한다', (tester) async {
      final bloc = await pumpEditor(tester);
      await goToStepTwo(tester, name: '보리');

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('말티즈').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('수컷'));
      await tester.enterText(
        find.byKey(const Key('pet_editor_description_field')),
        '사람을 좋아해요',
      );
      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();

      final event = verify(
        () => bloc.add(captureAny(that: isA<AddPetEvent>())),
      ).captured.single as AddPetEvent;
      expect(event.pet.name, '보리');
      expect(event.pet.breed, '말티즈');
      expect(event.pet.gender, PetGender.male);
      expect(event.pet.description, '사람을 좋아해요');
    });

    testWidgets('등록 2단계 Android back은 화면을 닫지 않고 1단계로 돌아간다', (tester) async {
      await pumpEditor(tester);
      await goToStepTwo(tester, name: '뒤로 유지');
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pet_editor_page')), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('pet_editor_name_field')),
      );
      expect(nameField.controller?.text, '뒤로 유지');
    });

    testWidgets('제출 중 중복 탭은 AddPetEvent를 중복 전송하지 않는다', (tester) async {
      final bloc = await pumpEditor(tester);
      await goToStepTwo(tester);
      final submit = find.byKey(const Key('pet_editor_primary_button'));
      await tester.tap(submit);
      await tester.pump();
      await tester.tap(submit, warnIfMissed: false);
      await tester.pump();
      verify(() => bloc.add(any(that: isA<AddPetEvent>()))).called(1);
    });

    testWidgets('수정은 같은 종류 재탭 품종과 미편집 Pet 필드를 보존한다', (tester) async {
      final original = buildPet();
      final bloc = await pumpEditor(tester, pet: original);

      expect(find.text('반려동물 정보'), findsOneWidget);
      expect(find.text('테스트 믹스'), findsOneWidget);
      expect(find.text('등록됨 · KOR'), findsOneWidget);
      await tester.tap(find.text('강아지'));
      await tester.pump();
      expect(find.text('테스트 믹스'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();
      final event = verify(
        () => bloc.add(captureAny(that: isA<UpdatePetEvent>())),
      ).captured.single as UpdatePetEvent;
      expect(event.pet.id, original.id);
      expect(event.pet.userId, original.userId);
      expect(event.pet.createdAt, original.createdAt);
      expect(event.pet.currentMbtiType, original.currentMbtiType);
      expect(event.pet.currentMbtiUpdatedAt, original.currentMbtiUpdatedAt);
      expect(event.pet.passportNo, original.passportNo);
      expect(event.pet.breed, original.breed);
    });

    testWidgets('수정에서 optional 품종·성별·생년월일을 명시적으로 비울 수 있다', (tester) async {
      final bloc = await pumpEditor(tester, pet: buildPet());
      final scrollable = find.byType(Scrollable).first;

      for (final key in const [
        Key('pet_editor_clear_breed_button'),
        Key('pet_editor_clear_birth_date_button'),
        Key('pet_editor_clear_gender_button'),
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(key),
          180,
          scrollable: scrollable,
        );
        await tester.tap(find.byKey(key));
        await tester.pump();
      }

      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();
      final event = verify(
        () => bloc.add(captureAny(that: isA<UpdatePetEvent>())),
      ).captured.single as UpdatePetEvent;
      expect(event.pet.breed, isNull);
      expect(event.pet.gender, isNull);
      expect(event.pet.birthDate, isNull);
    });

    testWidgets('수정 route data는 현재 인증 사용자와 pet 소유자가 같아야 한다', (tester) async {
      final bloc = _MockPetBloc();
      addTearDown(bloc.close);
      final data = PetEditorRouteData(petBloc: bloc, pet: buildPet());

      expect(data.matchesEdit(petId: 'pet-1', userId: 'user-1'), isTrue);
      expect(data.matchesEdit(petId: 'pet-1', userId: 'other-user'), isFalse);
      expect(data.matchesEdit(petId: 'other-pet', userId: 'user-1'), isFalse);
    });

    testWidgets('여권 draft의 대문자·국가 값을 최종 수정에 반영한다', (tester) async {
      final original = buildPet();
      final bloc = await pumpEditor(tester, pet: original);

      await tester.scrollUntilVisible(
        find.byKey(const Key('pet_editor_passport_manage_button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('pet_editor_passport_manage_button')))
            .height,
        greaterThanOrEqualTo(44),
      );
      await tester
          .tap(find.byKey(const Key('pet_editor_passport_manage_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pet_passport_editor_page')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('pet_passport_surname_field')), 'lee1');
      await tester.tap(find.byKey(const Key('pet_passport_country_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🇯🇵 일본 (JPN)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pet_passport_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('등록됨 · JPN'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();
      final event = verify(
        () => bloc.add(captureAny(that: isA<UpdatePetEvent>())),
      ).captured.single as UpdatePetEvent;
      expect(event.pet.passportSurname, 'LEE');
      expect(event.pet.countryCode, 'JPN');
      expect(event.pet.passportNo, original.passportNo);
    });

    testWidgets('성공 전에는 열려 있고 PetOperationSuccess 뒤 한 번만 닫힌다', (tester) async {
      final states = StreamController<PetState>();
      addTearDown(states.close);
      final bloc = await pumpEditor(tester, stateController: states);
      await goToStepTwo(tester);
      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();
      expect(find.byKey(const Key('pet_editor_page')), findsOneWidget);
      verify(() => bloc.add(any(that: isA<AddPetEvent>()))).called(1);

      states.add(PetLoading());
      await tester.pump();
      expect(find.byKey(const Key('pet_editor_page')), findsOneWidget);
      states.add(const PetOperationSuccess(message: '등록 완료', pets: []));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pet_editor_page')), findsNothing);
      expect(find.text('기준 화면'), findsOneWidget);

      states.add(const PetOperationSuccess(message: '중복 성공', pets: []));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('기준 화면'), findsOneWidget);
    });

    testWidgets('PetError는 단계를 유지하고 목록 재로딩 뒤 재시도할 수 있다', (tester) async {
      final states = StreamController<PetState>();
      addTearDown(states.close);
      final bloc = await pumpEditor(tester, stateController: states);
      await goToStepTwo(tester, name: '오류 유지');
      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();

      states.add(const PetError('저장 실패'));
      await tester.pump();
      expect(find.text('2 / 2'), findsOneWidget);
      verify(() => bloc.add(any(that: isA<LoadUserPets>()))).called(1);

      await tester.tap(find.byKey(const Key('pet_editor_previous_button')));
      await tester.pump();
      final preservedName = tester.widget<TextFormField>(
        find.byKey(const Key('pet_editor_name_field')),
      );
      expect(preservedName.controller?.text, '오류 유지');
      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pumpAndSettle();

      const reloaded = PetLoaded(pets: []);
      when(() => bloc.state).thenReturn(reloaded);
      states.add(reloaded);
      await tester.pump();
      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();
      verify(() => bloc.add(any(that: isA<AddPetEvent>()))).called(2);
    });

    testWidgets('목록 복구도 실패하면 저장 재시도로 다시 불러온 뒤 자동 제출한다', (tester) async {
      final states = StreamController<PetState>();
      addTearDown(states.close);
      const reloadError = PetError('목록 복구 실패');
      final bloc = await pumpEditor(
        tester,
        stateController: states,
        initialState: reloadError,
      );
      await goToStepTwo(tester, name: '복구 재시도');

      final retryButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('pet_editor_primary_button')),
      );
      expect(retryButton.onPressed, isNotNull);
      retryButton.onPressed!();
      await tester.pump();
      verify(() => bloc.add(any(that: isA<LoadUserPets>()))).called(1);
      verifyNever(() => bloc.add(any(that: isA<AddPetEvent>())));

      const reloaded = PetLoaded(pets: []);
      when(() => bloc.state).thenReturn(reloaded);
      states.add(reloaded);
      await tester.pump();
      await tester.pump();

      verify(() => bloc.add(any(that: isA<AddPetEvent>()))).called(1);
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('등록 재시도는 같은 draft ID와 업로드 URL을 재사용한다', (tester) async {
      final states = StreamController<PetState>();
      addTearDown(states.close);
      final imageFile = File('pet-editor-retry.png');
      final uploadService = _MockImageUploadService();
      when(() => uploadService.uploadPetAvatar(imageFile, any()))
          .thenAnswer((_) async => 'https://example.com/uploaded-avatar.jpg');
      final bloc = await pumpEditor(
        tester,
        stateController: states,
        imagePicker: (_) async => imageFile,
        imageUploadService: uploadService,
        selectedImageBuilder: (_) => const ColoredBox(
          color: Colors.transparent,
        ),
      );

      await tester.tap(find.byKey(const Key('pet_editor_avatar_button')));
      await tester.pump();
      await goToStepTwo(tester, name: '초안 재시도');
      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();

      states.add(const PetError('저장 실패'));
      await tester.pump();
      const reloaded = PetLoaded(pets: []);
      when(() => bloc.state).thenReturn(reloaded);
      states.add(reloaded);
      await tester.pump();
      await tester.tap(find.byKey(const Key('pet_editor_primary_button')));
      await tester.pump();

      final events = verify(
        () => bloc.add(captureAny(that: isA<AddPetEvent>())),
      ).captured.cast<AddPetEvent>().toList();
      expect(events, hasLength(2));
      expect(events[1].pet.id, events[0].pet.id);
      expect(events[1].pet.avatarUrl, events[0].pet.avatarUrl);
      verify(() => uploadService.uploadPetAvatar(imageFile, events[0].pet.id))
          .called(1);
    });

    testWidgets('비정상 route의 돌아가기는 pop 불가 시 반려동물 관리로 복귀한다', (tester) async {
      final router = GoRouter(
        initialLocation: '/broken-editor',
        routes: [
          GoRoute(
            path: '/broken-editor',
            builder: (_, __) => const PetEditorRouteErrorPage(),
          ),
          GoRoute(
            path: '/pets',
            builder: (_, __) => const Scaffold(body: Text('안전한 반려동물 관리')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('돌아가기'));
      await tester.pumpAndSettle();
      expect(find.text('안전한 반려동물 관리'), findsOneWidget);
    });

    testWidgets('주요 CTA는 검은색이 아니라 actionBase를 사용한다', (tester) async {
      await pumpEditor(tester);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('pet_editor_primary_button')),
      );
      final background =
          button.style?.backgroundColor?.resolve(<WidgetState>{});
      expect(background, AppTheme.actionBase);
      expect(background, isNot(Colors.black));
    });

    testWidgets('등록 사진 영역은 88px 가로형이고 단계 제목은 한 번만 노출된다', (tester) async {
      await pumpEditor(tester, surface: const Size(390, 844));

      final avatar = find.byKey(const Key('pet_editor_avatar_button'));
      final photoAction =
          find.byKey(const Key('pet_editor_photo_label_button'));
      expect(tester.getSize(avatar), const Size(88, 88));
      expect(tester.getTopLeft(photoAction).dx,
          greaterThan(tester.getTopRight(avatar).dx));
      expect(find.text('기본 정보'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('pet_editor_primary_button')))
            .height,
        greaterThanOrEqualTo(52),
      );

      await goToStepTwo(tester);
      expect(find.text('추가 정보'), findsOneWidget);
    });

    testWidgets('수정 사진 영역은 이름과 중복되지 않는 가로형 identity block이다', (tester) async {
      await pumpEditor(tester, pet: buildPet());
      final avatar = find.byKey(const Key('pet_editor_avatar_button'));
      final photoAction =
          find.byKey(const Key('pet_editor_photo_label_button'));
      expect(find.text('프로필 사진'), findsOneWidget);
      expect(find.text('몽이'), findsOneWidget);
      expect(tester.getSize(avatar), const Size(88, 88));
      expect(tester.getSize(photoAction).height, greaterThanOrEqualTo(44));
    });

    testWidgets('320x568·150%·키보드·다크모드에서 overflow 없이 CTA가 보인다', (tester) async {
      await pumpEditor(
        tester,
        theme: ThemeData.dark(),
        surface: const Size(320, 568),
        textScale: 1.5,
        keyboardInset: 220,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('pet_editor_primary_button')).hitTestable(),
        findsOneWidget,
      );

      await goToStepTwo(tester, name: '작은 화면');
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('pet_editor_skip_button')), findsOneWidget);
      expect(
        find.byKey(const Key('pet_editor_primary_button')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('닫기·선택·사진·CTA는 최소 44px 터치 영역이다', (tester) async {
      await pumpEditor(tester, surface: const Size(390, 1000));
      expect(
        tester.getSize(find.byKey(const Key('pet_editor_close_button'))).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester
            .getSize(find.byKey(const Key('pet_editor_photo_label_button')))
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey(PetType.dog))).height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester
            .getSize(find.byKey(const Key('pet_editor_primary_button')))
            .height,
        greaterThanOrEqualTo(44),
      );

      await goToStepTwo(tester, name: '터치 영역');
      expect(
        tester
            .getSize(find.byKey(const Key('pet_editor_birth_date_field')))
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSize(find.byKey(const Key('pet_editor_skip_button'))).height,
        greaterThanOrEqualTo(44),
      );
    });
  });
}
