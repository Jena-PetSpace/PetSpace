import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/ai_history.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/domain/repositories/emotion_repository.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/bloc/ai_history_bloc.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockEmotionRepository extends Mock implements EmotionRepository {}

class _FakeAiHistoryPetScope extends Fake implements AiHistoryPetScope {}

class _FakeAiHistoryCursor extends Fake implements AiHistoryCursor {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAiHistoryPetScope());
    registerFallbackValue(_FakeAiHistoryCursor());
    registerFallbackValue(AiHistoryTypeFilter.all);
    registerFallbackValue(AiHistoryDateRange.all);
  });

  late _MockEmotionRepository repository;
  late SharedPreferences preferences;
  final pet = Pet(
    id: 'pet-1',
    userId: 'user-1',
    name: '봄이',
    type: PetType.dog,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final emotionRecord = AiHistoryRecord.emotion(
    EmotionAnalysis(
      id: 'emotion-1',
      userId: 'user-1',
      petId: 'pet-1',
      petName: '봄이',
      imageUrl: '',
      localImagePath: '',
      emotions: const EmotionScores(
        happiness: 0.7,
        calm: 0.3,
        excitement: 0,
        curiosity: 0,
        anxiety: 0,
        fear: 0,
        sadness: 0,
        discomfort: 0,
      ),
      confidence: 0.8,
      analyzedAt: DateTime(2026, 7, 29),
      tags: const [],
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ai_history_last_pet_scope_v1:user-1': 'pet-1',
    });
    preferences = await SharedPreferences.getInstance();
    repository = _MockEmotionRepository();
    when(
      () => repository.getAiHistoryPage(
        userId: any(named: 'userId'),
        petScope: any(named: 'petScope'),
        activePetIds: any(named: 'activePetIds'),
        typeFilter: any(named: 'typeFilter'),
        dateRange: any(named: 'dateRange'),
        healthAttentionOnly: any(named: 'healthAttentionOnly'),
        cursor: any(named: 'cursor'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        AiHistoryPageBatch(
          records: [],
          nextCursor: AiHistoryCursor(
            emotionExhausted: true,
            healthExhausted: true,
          ),
          hasMore: false,
        ),
      ),
    );
  });

  blocTest<AiHistoryBloc, AiHistoryState>(
    '유효한 사용자별 마지막 반려동물 범위를 복원하고 실제 조회에 적용한다',
    build: () => AiHistoryBloc(
      repository: repository,
      preferences: preferences,
    ),
    act: (bloc) => bloc.add(
      AiHistoryContextChanged(userId: 'user-1', pets: [pet]),
    ),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(
        bloc.state.scope,
        const AiHistoryPetScope.registered('pet-1'),
      );
      expect(bloc.state.status, AiHistoryLoadStatus.success);
      verify(
        () => repository.getAiHistoryPage(
          userId: 'user-1',
          petScope: const AiHistoryPetScope.registered('pet-1'),
          activePetIds: const ['pet-1'],
          typeFilter: AiHistoryTypeFilter.all,
          dateRange: AiHistoryDateRange.all,
          healthAttentionOnly: false,
          cursor: const AiHistoryCursor.initial(),
          pageSize: 20,
        ),
      ).called(1);
    },
  );

  blocTest<AiHistoryBloc, AiHistoryState>(
    '필터 일치 항목이 뒤쪽에 있으면 빈 배치를 자동으로 넘겨 실제 기록을 찾는다',
    build: () {
      var calls = 0;
      when(
        () => repository.getAiHistoryPage(
          userId: any(named: 'userId'),
          petScope: any(named: 'petScope'),
          activePetIds: any(named: 'activePetIds'),
          typeFilter: any(named: 'typeFilter'),
          dateRange: any(named: 'dateRange'),
          healthAttentionOnly: any(named: 'healthAttentionOnly'),
          cursor: any(named: 'cursor'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls < 3) {
          return Right(
            AiHistoryPageBatch(
              records: const [],
              nextCursor: AiHistoryCursor(
                emotionBefore: DateTime(2026, 7, 29 - calls),
                healthBefore: DateTime(2026, 7, 29 - calls),
              ),
              hasMore: true,
            ),
          );
        }
        return Right(
          AiHistoryPageBatch(
            records: [emotionRecord],
            nextCursor: const AiHistoryCursor(
              emotionExhausted: true,
              healthExhausted: true,
            ),
            hasMore: false,
          ),
        );
      });
      return AiHistoryBloc(
        repository: repository,
        preferences: preferences,
      );
    },
    act: (bloc) => bloc.add(
      AiHistoryContextChanged(userId: 'user-1', pets: [pet]),
    ),
    wait: const Duration(milliseconds: 30),
    verify: (bloc) {
      expect(bloc.state.records, [emotionRecord]);
      expect(bloc.state.hasMore, isFalse);
      verify(
        () => repository.getAiHistoryPage(
          userId: any(named: 'userId'),
          petScope: any(named: 'petScope'),
          activePetIds: any(named: 'activePetIds'),
          typeFilter: any(named: 'typeFilter'),
          dateRange: any(named: 'dateRange'),
          healthAttentionOnly: any(named: 'healthAttentionOnly'),
          cursor: any(named: 'cursor'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(3);
    },
  );

  blocTest<AiHistoryBloc, AiHistoryState>(
    '이전 필터의 늦은 응답은 최신 필터 결과를 덮어쓰지 않는다',
    build: () {
      when(
        () => repository.getAiHistoryPage(
          userId: any(named: 'userId'),
          petScope: any(named: 'petScope'),
          activePetIds: any(named: 'activePetIds'),
          typeFilter: any(named: 'typeFilter'),
          dateRange: any(named: 'dateRange'),
          healthAttentionOnly: any(named: 'healthAttentionOnly'),
          cursor: any(named: 'cursor'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((invocation) async {
        final filter =
            invocation.namedArguments[#typeFilter] as AiHistoryTypeFilter;
        if (filter == AiHistoryTypeFilter.health) {
          await Future<void>.delayed(const Duration(milliseconds: 70));
          return const Right(
            AiHistoryPageBatch(
              records: [],
              nextCursor: AiHistoryCursor(
                emotionExhausted: true,
                healthExhausted: true,
              ),
              hasMore: false,
            ),
          );
        }
        if (filter == AiHistoryTypeFilter.emotion) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return Right(
            AiHistoryPageBatch(
              records: [emotionRecord],
              nextCursor: const AiHistoryCursor(
                emotionExhausted: true,
                healthExhausted: true,
              ),
              hasMore: false,
            ),
          );
        }
        return const Right(
          AiHistoryPageBatch(
            records: [],
            nextCursor: AiHistoryCursor(
              emotionExhausted: true,
              healthExhausted: true,
            ),
            hasMore: false,
          ),
        );
      });
      return AiHistoryBloc(
        repository: repository,
        preferences: preferences,
      );
    },
    act: (bloc) async {
      bloc.add(AiHistoryContextChanged(userId: 'user-1', pets: [pet]));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(
        const AiHistoryFiltersApplied(
          type: AiHistoryTypeFilter.health,
          dateRange: AiHistoryDateRange.all,
          healthAttentionOnly: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bloc.add(
        const AiHistoryFiltersApplied(
          type: AiHistoryTypeFilter.emotion,
          dateRange: AiHistoryDateRange.all,
          healthAttentionOnly: false,
        ),
      );
    },
    wait: const Duration(milliseconds: 120),
    verify: (bloc) {
      expect(bloc.state.typeFilter, AiHistoryTypeFilter.emotion);
      expect(bloc.state.records, [emotionRecord]);
    },
  );

  blocTest<AiHistoryBloc, AiHistoryState>(
    '확인할 건강 기록 토글을 끄면 전체 유형으로 복원한다',
    build: () => AiHistoryBloc(
      repository: repository,
      preferences: preferences,
    ),
    seed: () => AiHistoryState(
      userId: 'user-1',
      pets: [pet],
      typeFilter: AiHistoryTypeFilter.health,
      healthAttentionOnly: true,
    ),
    act: (bloc) => bloc.add(const AiHistoryAttentionChanged(false)),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.typeFilter, AiHistoryTypeFilter.all);
      expect(bloc.state.healthAttentionOnly, isFalse);
    },
  );
}
