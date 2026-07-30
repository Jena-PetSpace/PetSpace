import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';
import 'package:meong_nyang_diary/features/health/presentation/bloc/health_bloc.dart';
import 'package:meong_nyang_diary/features/health/presentation/controllers/health_emotion_loader.dart';
import 'package:meong_nyang_diary/features/health/presentation/pages/health_main_page.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

class _MockHealthBloc extends MockBloc<HealthEvent, HealthState>
    implements HealthBloc {}

class _StubEmotionLoader implements HealthEmotionLoader {
  @override
  Future<HealthEmotionHistoryResult> loadHistory({
    required String userId,
    required String petId,
    int limit = 30,
  }) async {
    return const HealthEmotionHistoryResult.success([]);
  }

  @override
  Future<EmotionAnalysis?> loadLatest({
    required String userId,
    required String petId,
  }) async {
    return null;
  }
}

final _pet = Pet(
  id: 'pet-1',
  userId: 'user-1',
  name: '보리',
  type: PetType.dog,
  breed: '비글',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

HealthRecord _record({
  required String id,
  required String title,
  HealthRecordType type = HealthRecordType.checkup,
  HealthRecordStatus status = HealthRecordStatus.completed,
  DateTime? nextDate,
}) {
  return HealthRecord(
    id: id,
    petId: _pet.id,
    userId: _pet.userId,
    recordType: type,
    title: title,
    recordDate: DateTime(2026, 7, 20),
    nextDate: nextDate,
    status: status,
    data: type == HealthRecordType.weight ? const {'weight_kg': 5.4} : const {},
    createdAt: DateTime(2026, 7, 20),
    updatedAt: DateTime(2026, 7, 20),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester, {
    required HealthLoaded state,
    Size surface = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authBloc = _MockAuthBloc();
    final petBloc = _MockPetBloc();
    final healthBloc = _MockHealthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthUnauthenticated(),
    );
    whenListen(
      petBloc,
      const Stream<PetState>.empty(),
      initialState: PetLoaded(pets: [_pet], selectedPet: _pet),
    );
    whenListen(
      healthBloc,
      const Stream<HealthState>.empty(),
      initialState: state,
    );
    addTearDown(authBloc.close);
    addTearDown(petBloc.close);
    addTearDown(healthBloc.close);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<PetBloc>.value(value: petBloc),
            ],
            child: HealthMainPage(
              healthBloc: healthBloc,
              emotionLoader: _StubEmotionLoader(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('다음 케어 단일 계산', () {
    testWidgets('0개면 헤더와 본문이 모두 예정 없음으로 일치한다', (tester) async {
      await pumpPage(
        tester,
        state: HealthLoaded(
          petId: _pet.id,
          records: const [],
          upcomingAlerts: const [],
        ),
      );

      expect(find.text('예정 없음'), findsOneWidget);
      expect(find.byKey(const Key('health_next_care_empty')), findsOneWidget);
      expect(find.byKey(const Key('health_next_care_item')), findsNothing);
    });

    testWidgets('1개면 헤더 수와 본문 첫 일정이 일치한다', (tester) async {
      final alert = _record(
        id: 'care-1',
        title: '예방접종',
        nextDate: DateTime(2026, 8, 1),
      );
      await pumpPage(
        tester,
        state: HealthLoaded(
          petId: _pet.id,
          records: [alert],
          upcomingAlerts: [alert],
        ),
      );

      expect(find.text('가까운 일정 1개'), findsOneWidget);
      expect(find.byKey(const Key('health_next_care_item')), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('health_next_care_title')),
            )
            .data,
        '예방접종',
      );
    });

    testWidgets('3개면 전체 수와 가장 가까운 1개 표시를 함께 알린다', (tester) async {
      final alerts = [
        _record(
          id: 'care-3',
          title: '세 번째 일정',
          nextDate: DateTime(2026, 9, 1),
        ),
        _record(
          id: 'care-1',
          title: '가장 가까운 일정',
          nextDate: DateTime(2026, 8, 1),
        ),
        _record(
          id: 'care-2',
          title: '두 번째 일정',
          nextDate: DateTime(2026, 8, 15),
        ),
      ];
      await pumpPage(
        tester,
        state: HealthLoaded(
          petId: _pet.id,
          records: alerts,
          upcomingAlerts: alerts,
        ),
      );

      expect(find.text('가까운 일정 3개 중 1개'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('health_next_care_title')),
            )
            .data,
        '가장 가까운 일정',
      );
    });

    testWidgets('dueDate가 없는 항목은 헤더와 본문에서 함께 제외한다', (tester) async {
      final invalidAlert = _record(id: 'no-date', title: '날짜 없는 기록');
      await pumpPage(
        tester,
        state: HealthLoaded(
          petId: _pet.id,
          records: [invalidAlert],
          upcomingAlerts: [invalidAlert],
        ),
      );

      expect(find.text('예정 없음'), findsOneWidget);
      expect(find.byKey(const Key('health_next_care_empty')), findsOneWidget);
      expect(find.text('날짜 없는 기록'), findsOneWidget);
    });
  });

  testWidgets('필터는 최근 기록 건수를 갱신하고 전체로 복원한다', (tester) async {
    final records = [
      _record(
        id: 'weight',
        title: '체중 기록',
        type: HealthRecordType.weight,
      ),
      _record(id: 'checkup', title: '검진 기록'),
    ];
    await pumpPage(
      tester,
      state: HealthLoaded(petId: _pet.id, records: records),
    );

    expect(find.text('전체 2건'), findsOneWidget);
    await tester.tap(find.byKey(const Key('health_filter_weight')));
    await tester.pump();
    expect(find.text('체중 1건'), findsOneWidget);
    expect(find.text('체중 기록'), findsOneWidget);
    expect(find.text('검진 기록'), findsNothing);

    await tester.tap(find.byKey(const Key('health_filter_all')));
    await tester.pump();
    expect(find.text('전체 2건'), findsOneWidget);
    expect(find.text('검진 기록'), findsOneWidget);
  });

  testWidgets('320x568·글자 200%에서도 추가 CTA가 스크롤로 도달 가능하다', (tester) async {
    await pumpPage(
      tester,
      state: HealthLoaded(petId: _pet.id, records: const []),
      surface: const Size(320, 568),
      textScale: 2,
    );

    final addCta = find.byKey(const Key('health_add_record_cta'));
    await tester.ensureVisible(addCta);
    await tester.pump();

    expect(addCta, findsOneWidget);
    expect(tester.getSize(addCta).height, greaterThanOrEqualTo(52));
    expect(tester.takeException(), isNull);
  });
}
