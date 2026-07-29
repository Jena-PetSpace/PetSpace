import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/domain/repositories/emotion_repository.dart';
import 'package:meong_nyang_diary/features/emotion/domain/usecases/get_previous_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/bloc/emotion_memo_cubit.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/pages/emotion_result_loader_page.dart';

class _MockEmotionRepository extends Mock implements EmotionRepository {}

class _FakeEmotionAnalysis extends Fake implements EmotionAnalysis {}

void main() {
  late _MockEmotionRepository repository;

  final analysis = EmotionAnalysis(
    id: 'analysis-1',
    userId: 'user-1',
    petId: 'pet-1',
    petName: '봄이',
    imageUrl: '',
    localImagePath: '',
    emotions: const EmotionScores(
      happiness: 0.7,
      calm: 0.2,
      excitement: 0.1,
      curiosity: 0,
      anxiety: 0,
      fear: 0,
      sadness: 0,
      discomfort: 0,
    ),
    confidence: 0.8,
    analyzedAt: DateTime(2026, 7, 29),
    tags: const [],
  );

  setUpAll(() {
    registerFallbackValue(_FakeEmotionAnalysis());
  });

  setUp(() async {
    repository = _MockEmotionRepository();
    when(() => repository.getAnalysisById('analysis-1'))
        .thenAnswer((_) async => Right(analysis));
    when(
      () => repository.getAnalysesByPet(
        petId: any(named: 'petId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Right([]));
  });

  testWidgets('ID loader는 항상 저장된 기록 모드로 상세를 연다', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 800),
        builder: (_, __) => MaterialApp(
          home: EmotionResultLoaderPage(
            analysisId: 'analysis-1',
            repository: repository,
            getPreviousAnalysis: GetPreviousAnalysis(repository),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('저장된 감정 기록'), findsWidgets);
    expect(find.textContaining('기록에서 열었어요'), findsOneWidget);
    verify(() => repository.getAnalysisById('analysis-1')).called(1);
    verifyNever(() => repository.saveAnalysis(any()));
  });

  test('기록 메모는 기존 행 UPDATE 성공 뒤에만 성공 상태가 된다', () async {
    final updated = analysis.copyWith(memo: '산책 후 편안해 보였어요');
    when(
      () => repository.updateAnalysisMemo(
        analysisId: 'analysis-1',
        memo: '산책 후 편안해 보였어요',
      ),
    ).thenAnswer((_) async => Right(updated));
    final cubit = EmotionMemoCubit(
      repository: repository,
      analysis: analysis,
    );

    final saved = await cubit.save('산책 후 편안해 보였어요');

    expect(saved, isTrue);
    expect(cubit.state.status, EmotionMemoStatus.success);
    expect(cubit.state.analysis.memo, '산책 후 편안해 보였어요');
    verify(
      () => repository.updateAnalysisMemo(
        analysisId: 'analysis-1',
        memo: '산책 후 편안해 보였어요',
      ),
    ).called(1);
    verifyNever(() => repository.saveAnalysis(any()));
    await cubit.close();
  });
}
