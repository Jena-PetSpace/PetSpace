import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';

HealthRecord _record({
  String id = 'record-1',
  String petId = 'pet-1',
  String? description,
  DateTime? recordDate,
  DateTime? nextDate,
  HealthRecordStatus status = HealthRecordStatus.completed,
  Map<String, dynamic> data = const {},
  DateTime? updatedAt,
}) {
  return HealthRecord(
    id: id,
    petId: petId,
    userId: 'user-1',
    recordType: HealthRecordType.checkup,
    title: '건강검진',
    description: description,
    recordDate: recordDate ?? DateTime(2026, 7, 20),
    nextDate: nextDate,
    status: status,
    data: data,
    createdAt: DateTime(2026, 7, 1),
    updatedAt: updatedAt ?? DateTime(2026, 7, 1),
  );
}

void main() {
  test('dueDate는 nextDate를 우선하고 예정 기록만 recordDate를 대체값으로 쓴다', () {
    final next = DateTime(2026, 8, 1);
    expect(_record(nextDate: next).dueDate, next);
    expect(
      _record(status: HealthRecordStatus.scheduled).dueDate,
      DateTime(2026, 7, 20),
    );
    expect(_record().dueDate, isNull);
  });

  test('D-day는 시각이 아니라 날짜 단위로 계산한다', () {
    final record = _record(
      nextDate: DateTime(2026, 7, 21, 1),
    );
    expect(record.daysUntilDue(DateTime(2026, 7, 20, 23, 59)), 1);
  });

  test('copyWith는 description과 nextDate를 명시적으로 해제할 수 있다', () {
    final original = _record(
      description: '메모',
      nextDate: DateTime(2026, 8, 1),
    );

    final cleared = original.copyWith(
      description: null,
      nextDate: null,
    );

    expect(cleared.description, isNull);
    expect(cleared.nextDate, isNull);
  });

  test('사용자에게 보이는 수정 가능 필드는 동등성에 포함된다', () {
    final original = _record(
      description: '이전',
      nextDate: DateTime(2026, 8, 1),
      data: const {'hospital': 'A'},
    );

    expect(original.copyWith(description: '변경'), isNot(original));
    expect(original.copyWith(nextDate: DateTime(2026, 9, 1)), isNot(original));
    expect(
      original.copyWith(data: const {'hospital': 'B'}),
      isNot(original),
    );
    expect(
      original.copyWith(updatedAt: DateTime(2026, 7, 2)),
      isNot(original),
    );
  });
}
