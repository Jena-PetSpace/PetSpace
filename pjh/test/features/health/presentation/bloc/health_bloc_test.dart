import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';
import 'package:meong_nyang_diary/features/health/domain/repositories/health_repository.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/add_health_record.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/delete_health_record.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/get_health_records.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/get_upcoming_records.dart';
import 'package:meong_nyang_diary/features/health/domain/usecases/update_health_record.dart';
import 'package:meong_nyang_diary/features/health/presentation/bloc/health_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockHealthRepository extends Mock implements HealthRepository {}

class _MockGetHealthRecords extends Mock implements GetHealthRecords {}

class _MockGetUpcomingRecords extends Mock implements GetUpcomingRecords {}

class _MockAddHealthRecord extends Mock implements AddHealthRecord {}

class _MockUpdateHealthRecord extends Mock implements UpdateHealthRecord {}

class _MockDeleteHealthRecord extends Mock implements DeleteHealthRecord {}

HealthRecord _record(String petId, {String id = 'record-1'}) => HealthRecord(
      id: id,
      petId: petId,
      userId: 'user-1',
      recordType: HealthRecordType.vaccination,
      title: '예방접종',
      recordDate: DateTime(2026, 7, 20),
      nextDate: DateTime(2026, 8, 20),
      status: HealthRecordStatus.completed,
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
    );

void main() {
  late _MockHealthRepository repository;
  late _MockGetHealthRecords getRecords;
  late _MockGetUpcomingRecords getUpcoming;
  late _MockAddHealthRecord addRecord;
  late _MockUpdateHealthRecord updateRecord;
  late _MockDeleteHealthRecord deleteRecord;
  late HealthBloc bloc;

  setUpAll(() {
    registerFallbackValue(
      const GetHealthRecordsParams(petId: 'fallback-pet'),
    );
    registerFallbackValue(
      const GetUpcomingRecordsParams(
        userId: 'fallback-user',
        petId: 'fallback-pet',
      ),
    );
    registerFallbackValue(AddHealthRecordParams(record: _record('fallback')));
    registerFallbackValue(
      UpdateHealthRecordParams(record: _record('fallback')),
    );
    registerFallbackValue(
      const DeleteHealthRecordParams(recordId: 'fallback-record'),
    );
  });

  setUp(() {
    repository = _MockHealthRepository();
    getRecords = _MockGetHealthRecords();
    getUpcoming = _MockGetUpcomingRecords();
    addRecord = _MockAddHealthRecord();
    updateRecord = _MockUpdateHealthRecord();
    deleteRecord = _MockDeleteHealthRecord();
    bloc = HealthBloc(
      healthRepository: repository,
      getHealthRecords: getRecords,
      addHealthRecord: addRecord,
      updateHealthRecord: updateRecord,
      deleteHealthRecord: deleteRecord,
      getUpcomingRecords: getUpcoming,
    );
  });

  tearDown(() => bloc.close());

  test('늦게 도착한 이전 반려동물 응답은 현재 화면을 덮지 않는다', () async {
    final oldRequest = Completer<Either<Failure, List<HealthRecord>>>();
    when(() => getRecords(
          const GetHealthRecordsParams(petId: 'pet-old'),
        )).thenAnswer((_) => oldRequest.future);
    when(() => getRecords(
          const GetHealthRecordsParams(petId: 'pet-new'),
        )).thenAnswer((_) async => Right([_record('pet-new')]));
    when(() => getUpcoming(any()))
        .thenAnswer((_) async => const Right(<HealthRecord>[]));

    bloc.add(const LoadHealthRecords(
      petId: 'pet-old',
      userId: 'user-1',
    ));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const LoadHealthRecords(
      petId: 'pet-new',
      userId: 'user-1',
    ));

    await bloc.stream.firstWhere(
      (state) => state is HealthLoaded && state.petId == 'pet-new',
    );
    oldRequest.complete(Right([_record('pet-old')]));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = bloc.state as HealthLoaded;
    expect(state.petId, 'pet-new');
    expect(state.records.single.petId, 'pet-new');
    verify(() => getUpcoming(const GetUpcomingRecordsParams(
          userId: 'user-1',
          petId: 'pet-new',
        ))).called(1);
  });

  test('추가 성공 뒤 같은 pet의 예정 목록을 다시 읽고 outcome을 확정한다', () async {
    final initial = _record('pet-1', id: 'old');
    final added = _record('pet-1', id: 'new');
    when(() => getRecords(any())).thenAnswer((_) async => Right([initial]));
    when(() => getUpcoming(any()))
        .thenAnswer((_) async => const Right(<HealthRecord>[]));
    when(() => addRecord(any())).thenAnswer((_) async => Right(added));

    bloc.add(const LoadHealthRecords(
      petId: 'pet-1',
      userId: 'user-1',
    ));
    await bloc.stream.firstWhere((state) => state is HealthLoaded);

    bloc.add(AddHealthRecordEvent(
      record: added,
      operationId: 'add-1',
    ));
    final result = await bloc.stream
        .where((state) => state is HealthLoaded)
        .cast<HealthLoaded>()
        .firstWhere((state) =>
            state.mutation.matches('add-1') &&
            state.mutation.phase == HealthMutationPhase.succeeded);

    expect(
        result.records.map((record) => record.id), containsAll(['new', 'old']));
    verify(() => getUpcoming(const GetUpcomingRecordsParams(
          userId: 'user-1',
          petId: 'pet-1',
        ))).called(2);
  });

  test('mutation 실패는 원래 목록과 입력 재시도용 실패 outcome을 보존한다', () async {
    final initial = _record('pet-1');
    when(() => getRecords(any())).thenAnswer((_) async => Right([initial]));
    when(() => getUpcoming(any()))
        .thenAnswer((_) async => const Right(<HealthRecord>[]));
    when(() => updateRecord(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'PostgrestException raw diagnostic'),
      ),
    );

    bloc.add(const LoadHealthRecords(
      petId: 'pet-1',
      userId: 'user-1',
    ));
    await bloc.stream.firstWhere((state) => state is HealthLoaded);

    bloc.add(UpdateHealthRecordEvent(
      record: initial.copyWith(title: '변경'),
      operationId: 'update-1',
    ));
    final result = await bloc.stream
        .where((state) => state is HealthLoaded)
        .cast<HealthLoaded>()
        .firstWhere((state) =>
            state.mutation.matches('update-1') &&
            state.mutation.phase == HealthMutationPhase.failed);

    expect(result.records.single.title, initial.title);
    expect(result.mutation.message, isNotEmpty);
    expect(result.mutation.message, isNot(contains('PostgrestException')));
    expect(result.mutation.message, contains('입력 내용은 유지'));
  });

  test('same-pet reload prevents a stale mutation from replacing fresh data',
      () async {
    final initial = _record('pet-1', id: 'initial');
    final staleAdded = _record('pet-1', id: 'stale-added');
    final refreshed = _record('pet-1', id: 'refreshed');
    final addRequest = Completer<Either<Failure, HealthRecord>>();
    var loadCount = 0;

    when(() => getRecords(any())).thenAnswer((_) async {
      loadCount += 1;
      return Right(loadCount == 1 ? [initial] : [refreshed]);
    });
    when(() => getUpcoming(any()))
        .thenAnswer((_) async => const Right(<HealthRecord>[]));
    when(() => addRecord(any())).thenAnswer((_) => addRequest.future);

    bloc.add(const LoadHealthRecords(
      petId: 'pet-1',
      userId: 'user-1',
    ));
    await bloc.stream.firstWhere((state) => state is HealthLoaded);

    bloc.add(AddHealthRecordEvent(
      record: staleAdded,
      operationId: 'add-stale',
    ));
    await bloc.stream.firstWhere(
      (state) =>
          state is HealthLoaded &&
          state.mutation.matches('add-stale') &&
          state.mutation.phase == HealthMutationPhase.pending,
    );

    bloc.add(const LoadHealthRecords(
      petId: 'pet-1',
      userId: 'user-1',
    ));
    await bloc.stream.firstWhere(
      (state) =>
          state is HealthLoaded && state.records.single.id == 'refreshed',
    );

    addRequest.complete(Right(staleAdded));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = bloc.state as HealthLoaded;
    expect(state.records.single.id, 'refreshed');
    expect(state.mutation.matches('add-stale'), isFalse);
  });
}
