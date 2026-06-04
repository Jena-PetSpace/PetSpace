import 'dart:io';
import 'dart:ui' as ui;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/config/injection_container.dart' show sl;
import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_content_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_seen_local_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/domain/services/fortune_generator.dart';
import 'package:meong_nyang_diary/features/fortune/presentation/widgets/home_fortune_card.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';

/// 홈 운세 카드 톤 검토용 캡처 (개발 도구 — CI 비포함).
///
/// 실행: flutter test test/features/fortune/fortune_home_card_capture.dart
/// 결과: build/fortune_screenshots/home_*.png
/// (toImage 헤드리스 한계로 teardown 타임아웃 가능 — PNG 는 기록됨)
class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

void main() {
  const outDir = 'build/fortune_screenshots';

  Pet pet(String id, String name, {String? mbti}) => Pet(
        id: id,
        userId: 'u1',
        name: name,
        type: PetType.dog,
        currentMbtiType: mbti,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Future<void> registerDeps() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<SharedPreferences>()) {
      sl.registerLazySingleton<SharedPreferences>(() => prefs);
    }
    if (!sl.isRegistered<FortuneContentDataSource>()) {
      sl.registerLazySingleton<FortuneContentDataSource>(
          () => FortuneContentDataSourceImpl());
    }
    if (!sl.isRegistered<FortuneGenerator>()) {
      sl.registerLazySingleton(() => const FortuneGenerator());
    }
    if (!sl.isRegistered<FortuneSeenLocalDataSource>()) {
      sl.registerLazySingleton<FortuneSeenLocalDataSource>(
          () => FortuneSeenLocalDataSourceImpl(prefs: prefs));
    }
    // 미리보기용 콘텐츠 선로드.
    await sl<FortuneContentDataSource>().loadContent();
  }

  Future<void> captureCard(
    WidgetTester tester,
    String name, {
    required bool seen,
  }) async {
    await registerDeps();
    final p = pet('home-pet-1', '초코', mbti: 'ENFP');
    if (seen) {
      await sl<FortuneSeenLocalDataSource>()
          .markSeen(p.id, fortuneDateKey());
    }

    final bloc = _MockPetBloc();
    when(() => bloc.state).thenReturn(PetLoaded(pets: [p], selectedPet: p));
    whenListen(bloc, const Stream<PetState>.empty(),
        initialState: PetLoaded(pets: [p], selectedPet: p));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Pretendard'),
          home: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: BlocProvider<PetBloc>.value(
              value: bloc,
              child: const Center(
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 390,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: HomeFortuneCard(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());

    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('capture: 홈 카드 미확인(CTA)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 3, 240 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await captureCard(tester, 'home_01_cta', seen: false);
  });

  testWidgets('capture: 홈 카드 확인 후(미리보기)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 3, 240 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await captureCard(tester, 'home_02_seen', seen: true);
  });
}
