import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/domain/usecases/analyze_emotion.dart';
import 'package:meong_nyang_diary/features/emotion/domain/usecases/delete_emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/domain/usecases/get_emotion_history.dart';
import 'package:meong_nyang_diary/features/emotion/domain/usecases/get_emotion_statistics.dart';
import 'package:meong_nyang_diary/features/emotion/domain/usecases/save_emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/bloc/emotion_analysis_bloc.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────
class MockAnalyzeEmotion extends Mock implements AnalyzeEmotion {}

class MockSaveEmotionAnalysis extends Mock implements SaveEmotionAnalysis {}

class MockGetEmotionHistory extends Mock implements GetEmotionHistory {}

class MockGetEmotionStatistics extends Mock implements GetEmotionStatistics {}

class MockDeleteEmotionAnalysis extends Mock implements DeleteEmotionAnalysis {}

// ── Fixtures ──────────────────────────────────────────────────────────────────
final _tAnalysis = EmotionAnalysis(
  id: 'analysis-001',
  userId: 'user-001',
  petId: 'pet-001',
  imageUrl: 'https://example.com/img.jpg',
  localImagePath: '/tmp/img.jpg',
  emotions: const EmotionScores(
    happiness: 0.80,
    sadness: 0.05,
    anxiety: 0.05,
    sleepiness: 0.05,
    curiosity: 0.05,
  ),
  confidence: 0.92,
  analyzedAt: DateTime(2025, 6, 1, 12, 0),
  tags: const ['test'],
);

// AnalyzeEmotionParams fallback 등록
class FakeAnalyzeEmotionParams extends Fake implements AnalyzeEmotionParams {}

class FakeSaveEmotionAnalysisParams extends Fake
    implements SaveEmotionAnalysisParams {}

class FakeGetEmotionHistoryParams extends Fake
    implements GetEmotionHistoryParams {}

class FakeGetEmotionStatisticsParams extends Fake
    implements GetEmotionStatisticsParams {}

class FakeDeleteEmotionAnalysisParams extends Fake
    implements DeleteEmotionAnalysisParams {}

void main() {
  late EmotionAnalysisBloc bloc;
  late MockAnalyzeEmotion mockAnalyze;
  late MockSaveEmotionAnalysis mockSave;
  late MockGetEmotionHistory mockHistory;
  late MockGetEmotionStatistics mockStatistics;
  late MockDeleteEmotionAnalysis mockDelete;

  setUpAll(() {
    registerFallbackValue(FakeAnalyzeEmotionParams());
    registerFallbackValue(FakeSaveEmotionAnalysisParams());
    registerFallbackValue(FakeGetEmotionHistoryParams());
    registerFallbackValue(FakeGetEmotionStatisticsParams());
    registerFallbackValue(FakeDeleteEmotionAnalysisParams());
  });

  setUp(() {
    mockAnalyze = MockAnalyzeEmotion();
    mockSave = MockSaveEmotionAnalysis();
    mockHistory = MockGetEmotionHistory();
    mockStatistics = MockGetEmotionStatistics();
    mockDelete = MockDeleteEmotionAnalysis();

    bloc = EmotionAnalysisBloc(
      analyzeEmotion: mockAnalyze,
      saveEmotionAnalysis: mockSave,
      getEmotionHistory: mockHistory,
      getEmotionStatistics: mockStatistics,
      deleteEmotionAnalysis: mockDelete,
    );
  });

  tearDown(() => bloc.close());

  // ── 초기 상태 ────────────────────────────────────────────────────────────────
  group('초기 상태', () {
    test('EmotionAnalysisInitial 로 시작', () {
      expect(bloc.state, isA<EmotionAnalysisInitial>());
    });
  });

  // ── AnalyzeEmotionRequested ───────────────────────────────────────────────────
  group('AnalyzeEmotionRequested', () {
    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '성공 → [Loading, Success]',
      build: () {
        when(() => mockAnalyze(any()))
            .thenAnswer((_) async => Right(_tAnalysis));
        return bloc;
      },
      act: (b) => b.add(const AnalyzeEmotionRequested(
        imagePaths: ['/tmp/img.jpg'],
        petId: 'pet-001',
      )),
      expect: () => [
        isA<EmotionAnalysisLoading>(),
        isA<EmotionAnalysisSuccess>()
            .having((s) => s.analysis.id, 'id', 'analysis-001')
            .having((s) => s.analysis.emotions.happiness, 'happiness', 0.80),
      ],
    );

    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '실패 → [Loading, Error]',
      build: () {
        when(() => mockAnalyze(any())).thenAnswer(
            (_) async => const Left(ServerFailure(message: 'AI 서버 오류')));
        return bloc;
      },
      act: (b) => b.add(const AnalyzeEmotionRequested(imagePaths: ['/tmp/img.jpg'])),
      expect: () => [
        isA<EmotionAnalysisLoading>(),
        isA<EmotionAnalysisError>()
            .having((s) => s.message, 'message', 'AI 서버 오류'),
      ],
    );
  });

  // ── SaveAnalysisRequested ─────────────────────────────────────────────────────
  group('SaveAnalysisRequested', () {
    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '성공 → [Saving, Saved]',
      build: () {
        when(() => mockSave(any())).thenAnswer((_) async => const Right(null));
        return bloc;
      },
      seed: () => EmotionAnalysisSuccess(_tAnalysis),
      act: (b) => b.add(const SaveAnalysisRequested(memo: '오늘도 행복한 몽이')),
      expect: () => [
        isA<EmotionAnalysisSaving>(),
        isA<EmotionAnalysisSaved>(),
      ],
    );

    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '저장할 분석 없으면 Error emit',
      build: () => bloc,
      seed: () => EmotionAnalysisInitial(),
      act: (b) => b.add(const SaveAnalysisRequested()),
      expect: () => [isA<EmotionAnalysisError>()],
    );

    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '저장 실패 → Error',
      build: () {
        when(() => mockSave(any())).thenAnswer(
            (_) async => const Left(DatabaseFailure(message: 'DB 저장 실패')));
        return bloc;
      },
      seed: () => EmotionAnalysisSuccess(_tAnalysis),
      act: (b) => b.add(const SaveAnalysisRequested()),
      expect: () => [
        isA<EmotionAnalysisSaving>(),
        isA<EmotionAnalysisError>(),
      ],
    );
  });

  // ── LoadAnalysisHistory ───────────────────────────────────────────────────────
  group('LoadAnalysisHistory', () {
    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '성공 → [HistoryLoading, HistoryLoaded]',
      build: () {
        when(() => mockHistory(any()))
            .thenAnswer((_) async => Right([_tAnalysis]));
        return bloc;
      },
      act: (b) => b.add(const LoadAnalysisHistory(userId: 'user-001')),
      expect: () => [
        isA<EmotionAnalysisHistoryLoading>(),
        isA<EmotionAnalysisHistoryLoaded>()
            .having((s) => s.history.length, 'count', 1),
      ],
    );

    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '빈 결과 → HistoryLoaded (빈 리스트)',
      build: () {
        when(() => mockHistory(any())).thenAnswer((_) async => const Right([]));
        return bloc;
      },
      act: (b) => b.add(const LoadAnalysisHistory(userId: 'user-001')),
      expect: () => [
        isA<EmotionAnalysisHistoryLoading>(),
        isA<EmotionAnalysisHistoryLoaded>()
            .having((s) => s.history, 'empty', isEmpty),
      ],
    );

    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '실패 → Error',
      build: () {
        when(() => mockHistory(any())).thenAnswer(
            (_) async => const Left(NetworkFailure(message: '네트워크 오류')));
        return bloc;
      },
      act: (b) => b.add(const LoadAnalysisHistory(userId: 'user-001')),
      expect: () => [
        isA<EmotionAnalysisHistoryLoading>(),
        isA<EmotionAnalysisError>(),
      ],
    );
  });

  // ── DeleteAnalysisRequested ───────────────────────────────────────────────────
  group('DeleteAnalysisRequested', () {
    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '성공 → EmotionAnalysisDeleted',
      build: () {
        when(() => mockDelete(any()))
            .thenAnswer((_) async => const Right(null));
        return bloc;
      },
      act: (b) => b.add(const DeleteAnalysisRequested(analysisId: 'analysis-001')),
      expect: () => [
        isA<EmotionAnalysisDeleted>(),
      ],
    );

    blocTest<EmotionAnalysisBloc, EmotionAnalysisState>(
      '실패 → Error',
      build: () {
        when(() => mockDelete(any())).thenAnswer(
            (_) async => const Left(DatabaseFailure(message: '삭제 실패')));
        return bloc;
      },
      act: (b) => b.add(const DeleteAnalysisRequested(analysisId: 'analysis-001')),
      expect: () => [isA<EmotionAnalysisError>()],
    );
  });
}
