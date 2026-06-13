import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/domain/repositories/emotion_repository.dart';
import 'package:meong_nyang_diary/features/emotion/domain/usecases/get_previous_analysis.dart';

class MockEmotionRepository extends Mock implements EmotionRepository {}

EmotionAnalysis _a(String id, DateTime at) =>
    EmotionAnalysis.empty().copyWith(id: id, petId: 'p1', analyzedAt: at);

void main() {
  late MockEmotionRepository repo;
  late GetPreviousAnalysis usecase;
  final current = _a('new', DateTime(2026, 6, 13, 12, 0));

  setUp(() {
    repo = MockEmotionRepository();
    usecase = GetPreviousAnalysis(repo);
  });

  test('현재보다 이전 분석이 있으면 그 중 최신 1건 반환', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5)).thenAnswer(
      (_) async => Right([
        _a('new', DateTime(2026, 6, 13, 12, 0)),
        _a('prev', DateTime(2026, 6, 13, 11, 0)),
        _a('older', DateTime(2026, 6, 10, 9, 0)),
      ]),
    );
    final result = await usecase(current: current);
    expect(result?.id, 'prev');
  });

  test('저장 전이라 방금 결과가 목록에 없어도 직전 1건 반환', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5)).thenAnswer(
      (_) async => Right([
        _a('prev', DateTime(2026, 6, 13, 11, 0)),
        _a('older', DateTime(2026, 6, 10, 9, 0)),
      ]),
    );
    final result = await usecase(current: current);
    expect(result?.id, 'prev');
  });

  test('이전 분석이 없으면(방금 1건뿐) null', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5)).thenAnswer(
      (_) async => Right([_a('new', DateTime(2026, 6, 13, 12, 0))]),
    );
    final result = await usecase(current: current);
    expect(result, isNull);
  });

  test('0건이면 null', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5))
        .thenAnswer((_) async => const Right([]));
    final result = await usecase(current: current);
    expect(result, isNull);
  });

  test('repository Left(Failure)면 null (throw 안 함)', () async {
    when(() => repo.getAnalysesByPet(petId: 'p1', limit: 5))
        .thenAnswer((_) async => const Left(ServerFailure(message: 'x')));
    final result = await usecase(current: current);
    expect(result, isNull);
  });

  test('petId가 null이면 조회 없이 null', () async {
    // copyWith은 null을 기존 값으로 폴백하므로 생성자 직접 호출
    final noPet = EmotionAnalysis(
      id: 'x',
      userId: '',
      petId: null,
      imageUrl: '',
      localImagePath: '',
      emotions: const EmotionScores(
        happiness: 0.125,
        calm: 0.125,
        excitement: 0.125,
        curiosity: 0.125,
        anxiety: 0.125,
        fear: 0.125,
        sadness: 0.125,
        discomfort: 0.125,
      ),
      confidence: 0.0,
      analyzedAt: DateTime(2026, 6, 13),
      tags: const [],
    );
    final result = await usecase(current: noPet);
    expect(result, isNull);
    verifyNever(() => repo.getAnalysesByPet(
        petId: any(named: 'petId'), limit: any(named: 'limit')));
  });
}
