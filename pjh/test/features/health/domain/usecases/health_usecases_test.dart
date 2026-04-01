import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';
import 'package:meong_nyang_diary/features/health/domain/repositories/health_repository.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/get_health_records.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/add_health_record.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/update_health_record.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/delete_health_record.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/get_upcoming_records.dart';

class MockHealthRepository extends Mock implements HealthRepository {}

final _tRecord = HealthRecord(
  id: 'record-001',
  petId: 'pet-001',
  userId: 'user-001',
  recordType: HealthRecordType.vaccination,
  title: '종합백신 5차',
  recordDate: DateTime(2025, 6, 1),
  status: HealthRecordStatus.completed,
  createdAt: DateTime(2025, 6, 1),
  updatedAt: DateTime(2025, 6, 1),
);

void main() {
  late MockHealthRepository repo;

  setUp(() => repo = MockHealthRepository());

  // ── GetHealthRecords ───────────────────────────────────────────────────────
  group('GetHealthRecords', () {
    test('성공 → Right(List<HealthRecord>)', () async {
      when(() => repo.getHealthRecords(
              petId: any(named: 'petId'), limit: any(named: 'limit')))
          .thenAnswer((_) async => Right([_tRecord]));

      final uc = GetHealthRecords(repo);
      final result = await uc(const GetHealthRecordsParams(petId: 'pet-001'));

      expect(result, Right([_tRecord]));
      verify(() => repo.getHealthRecords(petId: 'pet-001', limit: 50))
          .called(1);
    });

    test('네트워크 실패 → Left(NetworkFailure)', () async {
      when(() =>
          repo.getHealthRecords(
              petId: any(named: 'petId'),
              limit: any(named: 'limit'))).thenAnswer(
          (_) async => const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.')));

      final uc = GetHealthRecords(repo);
      final result = await uc(const GetHealthRecordsParams(petId: 'pet-001'));

      expect(result.isLeft(), true);
    });

    test('type 필터 파라미터 전달 확인', () async {
      when(() => repo.getHealthRecords(
            petId: any(named: 'petId'),
            type: any(named: 'type'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => const Right([]));

      final uc = GetHealthRecords(repo);
      await uc(const GetHealthRecordsParams(
        petId: 'pet-001',
        type: HealthRecordType.vaccination,
      ));

      verify(() => repo.getHealthRecords(
            petId: 'pet-001',
            type: HealthRecordType.vaccination,
            limit: 50,
          )).called(1);
    });
  });

  // ── AddHealthRecord ────────────────────────────────────────────────────────
  group('AddHealthRecord', () {
    test('성공 → Right(HealthRecord)', () async {
      when(() => repo.addHealthRecord(any()))
          .thenAnswer((_) async => Right(_tRecord));

      final uc = AddHealthRecord(repo);
      final result = await uc(AddHealthRecordParams(record: _tRecord));

      expect(result, Right(_tRecord));
    });

    test('실패 → Left(DatabaseFailure)', () async {
      when(() => repo.addHealthRecord(any())).thenAnswer(
          (_) async => const Left(DatabaseFailure(message: 'DB 오류')));

      final uc = AddHealthRecord(repo);
      final result = await uc(AddHealthRecordParams(record: _tRecord));

      expect(result.isLeft(), true);
    });
  });

  // ── UpdateHealthRecord ─────────────────────────────────────────────────────
  group('UpdateHealthRecord', () {
    test('성공 → Right(HealthRecord)', () async {
      final updated = _tRecord.copyWith(title: '종합백신 6차');
      when(() => repo.updateHealthRecord(any()))
          .thenAnswer((_) async => Right(updated));

      final uc = UpdateHealthRecord(repo);
      final result = await uc(UpdateHealthRecordParams(record: updated));

      result.fold(
        (f) => fail('Should not fail'),
        (r) => expect(r.title, '종합백신 6차'),
      );
    });
  });

  // ── DeleteHealthRecord ─────────────────────────────────────────────────────
  group('DeleteHealthRecord', () {
    test('성공 → Right(void)', () async {
      when(() => repo.deleteHealthRecord(any()))
          .thenAnswer((_) async => const Right(null));

      final uc = DeleteHealthRecord(repo);
      final result = await uc(const DeleteHealthRecordParams(recordId: 'record-001'));

      expect(result.isRight(), true);
      verify(() => repo.deleteHealthRecord('record-001')).called(1);
    });

    test('실패 → Left', () async {
      when(() => repo.deleteHealthRecord(any()))
          .thenAnswer((_) async => const Left(ServerFailure(message: '삭제 실패')));

      final uc = DeleteHealthRecord(repo);
      final result = await uc(const DeleteHealthRecordParams(recordId: 'record-001'));

      expect(result.isLeft(), true);
    });
  });

  // ── GetUpcomingRecords ─────────────────────────────────────────────────────
  group('GetUpcomingRecords', () {
    test('성공 → Right(List) 30일 이내 예정', () async {
      when(() => repo.getUpcomingRecords(
            userId: any(named: 'userId'),
            daysAhead: any(named: 'daysAhead'),
          )).thenAnswer((_) async => Right([_tRecord]));

      final uc = GetUpcomingRecords(repo);
      final result = await uc(const GetUpcomingRecordsParams(userId: 'user-001'));

      expect(result.isRight(), true);
      verify(() => repo.getUpcomingRecords(userId: 'user-001', daysAhead: 30))
          .called(1);
    });

    test('빈 결과 → Right([])', () async {
      when(() => repo.getUpcomingRecords(
            userId: any(named: 'userId'),
            daysAhead: any(named: 'daysAhead'),
          )).thenAnswer((_) async => const Right([]));

      final uc = GetUpcomingRecords(repo);
      final result = await uc(const GetUpcomingRecordsParams(userId: 'user-001'));

      result.fold((f) => fail('fail'), (list) => expect(list, isEmpty));
    });
  });
}
