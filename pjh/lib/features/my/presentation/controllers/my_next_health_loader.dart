import '../../../health/domain/entities/health_record.dart';
import '../../../health/domain/repositories/health_repository.dart';

/// MY 대표 카드가 필요한 가장 가까운 일정 한 건만 안전하게 조회한다.
class MyNextHealthLoader {
  final HealthRepository repository;

  const MyNextHealthLoader(this.repository);

  Future<HealthRecord?> call({
    required String userId,
    required String petId,
  }) async {
    final result = await repository.getUpcomingRecords(
      userId: userId,
      petId: petId,
      daysAhead: 365,
    );

    return result.fold(
      (_) => throw StateError('my-next-health-load-failed'),
      (records) {
        final schedulable = records
            .where(
              (record) =>
                  record.dueDate != null &&
                  record.status != HealthRecordStatus.cancelled,
            )
            .toList()
          ..sort((left, right) {
            final dateOrder = left.dueDate!.compareTo(right.dueDate!);
            return dateOrder != 0 ? dateOrder : left.id.compareTo(right.id);
          });
        return schedulable.isEmpty ? null : schedulable.first;
      },
    );
  }
}
