import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/ai_history.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/bloc/ai_history_bloc.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/pages/ai_history_page.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/history/ai_history_record_card.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';

class _MockAiHistoryBloc extends MockBloc<AiHistoryEvent, AiHistoryState>
    implements AiHistoryBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AiHistoryRefreshRequested());
  });

  EmotionAnalysis emotion({
    String id = 'emotion-1',
    double confidence = 0.72,
  }) {
    return EmotionAnalysis(
      id: id,
      userId: 'user-1',
      petId: 'pet-1',
      petName: '봄이',
      imageUrl: '',
      localImagePath: '',
      emotions: const EmotionScores(
        happiness: 0.8,
        calm: 0.2,
        excitement: 0,
        curiosity: 0,
        anxiety: 0,
        fear: 0,
        sadness: 0,
        discomfort: 0,
      ),
      confidence: confidence,
      analyzedAt: DateTime(2026, 7, 30, 10, 30),
      tags: const [],
    );
  }

  Pet pet() => Pet(
        id: 'pet-1',
        userId: 'user-1',
        name: '봄이',
        type: PetType.dog,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  Future<_MockAiHistoryBloc> pumpPage(
    WidgetTester tester,
    AiHistoryState state, {
    double textScale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final historyBloc = _MockAiHistoryBloc();
    final authBloc = _MockAuthBloc();
    final petBloc = _MockPetBloc();
    whenListen(
      historyBloc,
      const Stream<AiHistoryState>.empty(),
      initialState: state,
    );
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthUnauthenticated(),
    );
    whenListen(
      petBloc,
      const Stream<PetState>.empty(),
      initialState: PetInitial(),
    );
    when(() => historyBloc.add(any())).thenReturn(null);

    addTearDown(historyBloc.close);
    addTearDown(authBloc.close);
    addTearDown(petBloc.close);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<PetBloc>.value(value: petBloc),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: AiHistoryPage(historyBloc: historyBloc),
          ),
        ),
      ),
    );
    await tester.pump();
    return historyBloc;
  }

  testWidgets('빈 상태·전체 실패·추가 로딩은 서로 다른 복구 UI를 사용한다', (tester) async {
    await pumpPage(
      tester,
      const AiHistoryState(
        userId: 'user-1',
        status: AiHistoryLoadStatus.success,
      ),
    );
    expect(find.text('아직 저장된 분석 기록이 없어요'), findsOneWidget);
    expect(find.text('기록을 불러오지 못했어요'), findsNothing);

    await pumpPage(
      tester,
      const AiHistoryState(
        userId: 'user-1',
        status: AiHistoryLoadStatus.failure,
        errorMessage: 'sdk-private-detail',
      ),
    );
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('sdk-private-detail'), findsNothing);
    expect(find.text('아직 저장된 분석 기록이 없어요'), findsNothing);

    await pumpPage(
      tester,
      const AiHistoryState(
        userId: 'user-1',
        status: AiHistoryLoadStatus.success,
        isLoadingMore: true,
        hasMore: true,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('기록을 불러오지 못했어요'), findsNothing);
  });

  testWidgets('부분 실패는 안전한 인라인 안내와 기존 목록을 함께 유지한다', (tester) async {
    final record = AiHistoryRecord.emotion(emotion(), petName: '봄이');
    await pumpPage(
      tester,
      AiHistoryState(
        userId: 'user-1',
        status: AiHistoryLoadStatus.success,
        records: [record],
        errorMessage: 'raw repository payload',
      ),
    );

    expect(find.byType(AiHistoryRecordCard), findsOneWidget);
    expect(
      find.textContaining('일부 기록을 새로 불러오지 못했어요'),
      findsOneWidget,
    );
    expect(find.text('raw repository payload'), findsNothing);
  });

  testWidgets('펫 범위 선택은 기록 조회 이벤트로 이어진다', (tester) async {
    final historyBloc = await pumpPage(
      tester,
      AiHistoryState(
        userId: 'user-1',
        pets: [pet()],
        status: AiHistoryLoadStatus.success,
      ),
    );

    await tester.tap(find.text('전체 기록').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('봄이'));
    await tester.pump();

    verify(
      () => historyBloc.add(
        const AiHistoryScopeChanged(
          AiHistoryPetScope.registered('pet-1'),
        ),
      ),
    ).called(1);
  });

  testWidgets('기록 카드는 원시 퍼센트 없이 정성 밴드와 비진단 문구를 표시한다', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          home: Scaffold(
            body: AiHistoryRecordCard(
              record: AiHistoryRecord.emotion(
                emotion(confidence: 0.92),
                petName: '봄이',
              ),
              petLabel: '봄이',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('분석 근거 높음'), findsOneWidget);
    expect(find.textContaining('진단 결과가 아니에요'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('320x568 200% 글자에서도 흐름 카드와 주요 선택 액션이 렌더된다', (tester) async {
    await pumpPage(
      tester,
      AiHistoryState(
        userId: 'user-1',
        pets: [pet()],
        scope: const AiHistoryPetScope.registered('pet-1'),
        segment: AiHistorySegment.flow,
        status: AiHistoryLoadStatus.success,
        flowStatus: AiHistoryLoadStatus.success,
        daySignals: [
          AiHistoryDaySignal(
            day: DateTime(2026, 7, 29),
            dominantEmotion: 'happiness',
            hasMixedSignals: false,
            analysisCount: 2,
          ),
          AiHistoryDaySignal(
            day: DateTime(2026, 7, 30),
            dominantEmotion: 'calm',
            hasMixedSignals: true,
            analysisCount: 1,
          ),
        ],
      ),
      textScale: 2,
      size: const Size(320, 568),
    );

    expect(find.text('감정 흐름'), findsOneWidget);
    expect(find.text('여러 신호 함께'), findsOneWidget);
    expect(find.text('7일'), findsOneWidget);
    expect(find.text('30일'), findsWidgets);
    expect(find.text('90일'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
