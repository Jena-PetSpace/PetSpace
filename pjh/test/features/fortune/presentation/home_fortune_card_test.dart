import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/config/injection_container.dart' show sl;
import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_content_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_seen_local_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/domain/services/fortune_generator.dart';
import 'package:meong_nyang_diary/features/fortune/presentation/widgets/fortune_stars.dart';
import 'package:meong_nyang_diary/features/fortune/presentation/widgets/home_fortune_card.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';

class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FortuneSeenLocalDataSource seenStore;

  Pet dogPet(String id, String name, {String? mbti}) => Pet(
        id: id,
        userId: 'u1',
        name: name,
        type: PetType.dog,
        currentMbtiType: mbti,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // GetIt 재등록(테스트 격리).
    if (sl.isRegistered<SharedPreferences>()) {
      await sl.unregister<SharedPreferences>();
    }
    sl.registerLazySingleton<SharedPreferences>(() => prefs);

    if (!sl.isRegistered<FortuneContentDataSource>()) {
      sl.registerLazySingleton<FortuneContentDataSource>(
          () => FortuneContentDataSourceImpl());
    }
    if (!sl.isRegistered<FortuneGenerator>()) {
      sl.registerLazySingleton(() => const FortuneGenerator());
    }
    if (sl.isRegistered<FortuneSeenLocalDataSource>()) {
      await sl.unregister<FortuneSeenLocalDataSource>();
    }
    sl.registerLazySingleton<FortuneSeenLocalDataSource>(
        () => FortuneSeenLocalDataSourceImpl(prefs: prefs));
    seenStore = sl<FortuneSeenLocalDataSource>();

    await sl<FortuneContentDataSource>().loadContent();
  });

  Future<void> pumpCard(WidgetTester tester, Pet p) async {
    final bloc = _MockPetBloc();
    final state = PetLoaded(pets: [p], selectedPet: p);
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<PetState>.empty(), initialState: state);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: BlocProvider<PetBloc>.value(
              value: bloc,
              child: const HomeFortuneCard(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('미확인 → CTA(확인하기) 노출', (tester) async {
    await pumpCard(tester, dogPet('p1', '초코'));
    expect(find.text('확인하기'), findsOneWidget);
    expect(find.text('초코의 오늘의 운세'), findsOneWidget);
    // 확인 후 전용 요소(별 미리보기)는 아직 없음
    expect(find.byType(FortuneStars), findsNothing);
  });

  testWidgets('확인 후 → 미리보기(종합운 한 줄 + 별점) 노출', (tester) async {
    final p = dogPet('p2', '초코', mbti: 'ENFP');
    await seenStore.markSeen(p.id, fortuneDateKey());
    await pumpCard(tester, p);

    // CTA 칩 대신 미리보기. 종합 별점 위젯 존재.
    expect(find.text('확인하기'), findsNothing);
    expect(find.byType(FortuneStars), findsOneWidget);
    // 종합운 한 줄 + 진입 chevron
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('seen 키는 pet 단위 — 다른 pet 확인이 영향 없음', (tester) async {
    await seenStore.markSeen('p-other', fortuneDateKey());
    await pumpCard(tester, dogPet('p3', '몽이'));
    // p3 는 미확인 → CTA
    expect(find.text('확인하기'), findsOneWidget);
  });

  testWidgets('어제 확인 키가 있어도 오늘은 미확인(자정 경계)', (tester) async {
    final p = dogPet('p4', '초코');
    final yesterday = fortuneDateKey(
        DateTime.now().subtract(const Duration(days: 1)));
    await seenStore.markSeen(p.id, yesterday);
    await pumpCard(tester, p);
    // 어제 키는 오늘과 다른 키 → 오늘 미확인 → CTA
    expect(find.text('확인하기'), findsOneWidget);
  });
}
