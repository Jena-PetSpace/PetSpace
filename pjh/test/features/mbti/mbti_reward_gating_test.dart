import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/mbti/data/datasources/mbti_content_data_source.dart';
import 'package:meong_nyang_diary/features/mbti/data/datasources/mbti_draft_local_data_source.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/mbti_content.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';
import 'package:meong_nyang_diary/features/mbti/domain/repositories/mbti_repository.dart';
import 'package:meong_nyang_diary/features/mbti/domain/services/mbti_scorer.dart';
import 'package:meong_nyang_diary/features/mbti/domain/usecases/save_mbti_result.dart';
import 'package:meong_nyang_diary/features/mbti/presentation/bloc/mbti_test_bloc.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';

class _MockContentDS extends Mock implements MbtiContentDataSource {}

class _MockDraftDS extends Mock implements MbtiDraftLocalDataSource {}

class _MockMbtiRepo extends Mock implements MbtiRepository {}

class _MockSaveUC extends Mock implements SaveMbtiResult {}

class _MockSocialRepo extends Mock implements SocialRepository {}

PetMbtiResult _result(String petId) => PetMbtiResult(
      id: 'r1',
      petId: petId,
      species: MbtiSpecies.dog,
      typeCode: 'ENFP',
      axisScores: const {},
      answers: const [],
      contentVersion: 1,
      createdAt: DateTime(2026, 6, 4),
    );

void main() {
  // 실제 번들 콘텐츠(20문항)를 로드하기 위해 바인딩 초기화.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MbtiContent content;
  late _MockContentDS contentDS;
  late _MockDraftDS draftDS;
  late _MockMbtiRepo mbtiRepo;
  late _MockSaveUC saveUC;
  late _MockSocialRepo socialRepo;

  setUpAll(() async {
    content = await MbtiContentDataSourceImpl().loadContent();
    registerFallbackValue(SaveMbtiResultParams(result: _result('p')));
    registerFallbackValue(const MbtiDraft(
      petId: 'p',
      species: MbtiSpecies.dog,
      contentVersion: 1,
      answers: [],
      currentIndex: 0,
    ));
  });

  setUp(() {
    contentDS = _MockContentDS();
    draftDS = _MockDraftDS();
    mbtiRepo = _MockMbtiRepo();
    saveUC = _MockSaveUC();
    socialRepo = _MockSocialRepo();

    when(() => contentDS.loadContent(version: any(named: 'version')))
        .thenAnswer((_) async => content);
    when(() => draftDS.loadDraft(any(),
            expectedContentVersion: any(named: 'expectedContentVersion')))
        .thenAnswer((_) async => null);
    when(() => draftDS.clearDraft(any())).thenAnswer((_) async {});
    when(() => draftDS.saveDraft(any())).thenAnswer((_) async {});
    when(() => saveUC(any()))
        .thenAnswer((_) async => Right(_result('pet-1')));
    when(() => socialRepo.incrementUserPoints(
            userId: any(named: 'userId'), points: any(named: 'points')))
        .thenAnswer((_) async => const Right(null));
    when(() => socialRepo.awardBadgeIfAbsent(
            userId: any(named: 'userId'), badgeId: any(named: 'badgeId')))
        .thenAnswer((_) async => const Right(true));
  });

  MbtiTestBloc build() => MbtiTestBloc(
        contentDataSource: contentDS,
        draftDataSource: draftDS,
        scorer: const MbtiScorer(),
        saveMbtiResult: saveUC,
        mbtiRepository: mbtiRepo,
        socialRepository: socialRepo,
      );

  /// 강아지 20문항 전부 A 응답으로 채운 BLoC 을 inProgress 까지 만든다.
  Future<MbtiTestBloc> startedAndAnswered() async {
    final bloc = build();
    bloc.add(const MbtiTestStarted(petId: 'pet-1', species: MbtiSpecies.dog));
    await Future.delayed(const Duration(milliseconds: 30));
    bloc.add(const MbtiTestRestarted());
    await Future.delayed(const Duration(milliseconds: 20));
    // 20문항 A 응답
    for (var i = 0; i < content.questionsFor(MbtiSpecies.dog).length; i++) {
      bloc.add(const MbtiAnswered(0));
      await Future.delayed(const Duration(milliseconds: 2));
    }
    return bloc;
  }

  group('보상 게이팅 — 단일 소스(BLoC) / getLatestResult 동일 기준', () {
    test('제출 시 getLatestResult 로 첫 검사 여부를 판정한다', () async {
      when(() => mbtiRepo.getLatestResult(any()))
          .thenAnswer((_) async => const Right(null));

      final bloc = await startedAndAnswered();
      bloc.add(const MbtiSubmitted());
      await Future.delayed(const Duration(milliseconds: 50));

      // 적립 판정을 위해 getLatestResult 가 반드시 조회되어야 한다.
      verify(() => mbtiRepo.getLatestResult('pet-1')).called(1);
      await bloc.close();
    });

    test('둘째 검사(이전 결과 존재) → 포인트/뱃지 적립 분기 미진입', () async {
      when(() => mbtiRepo.getLatestResult(any()))
          .thenAnswer((_) async => Right(_result('pet-1'))); // 이전 결과 있음

      final bloc = await startedAndAnswered();
      bloc.add(const MbtiSubmitted());
      await Future.delayed(const Duration(milliseconds: 50));

      // 첫 검사가 아니므로 적립 메서드가 호출되지 않아야 한다(중복 적립 방지).
      verifyNever(() => socialRepo.incrementUserPoints(
          userId: any(named: 'userId'), points: any(named: 'points')));
      verifyNever(() => socialRepo.awardBadgeIfAbsent(
          userId: any(named: 'userId'), badgeId: any(named: 'badgeId')));
      await bloc.close();
    });

    test('보상 상수 (30pt / mbti_explorer)', () {
      expect(kMbtiFirstTestPoints, 30);
      expect(kMbtiExplorerBadgeId, 'mbti_explorer');
    });
  });
}
