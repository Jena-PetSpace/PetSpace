import 'package:equatable/equatable.dart';

class HealthRecord extends Equatable {
  static const Object _notProvided = Object();

  final String id;
  final String petId;
  final String userId;
  final HealthRecordType recordType;
  final String title;
  final String? description;
  final DateTime recordDate;
  final DateTime? nextDate;
  final HealthRecordStatus status;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HealthRecord({
    required this.id,
    required this.petId,
    required this.userId,
    required this.recordType,
    required this.title,
    this.description,
    required this.recordDate,
    this.nextDate,
    required this.status,
    this.data = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// 화면·정렬·예정 목록이 함께 사용하는 단일 일정 기준일.
  ///
  /// 반복 일정은 [nextDate], 아직 수행되지 않은 예정 기록은
  /// [recordDate]를 사용한다. 완료·취소 기록에 다음 일정이 없으면 null이다.
  DateTime? get dueDate {
    if (nextDate != null) return nextDate;
    return status == HealthRecordStatus.scheduled ? recordDate : null;
  }

  int? daysUntilDue([DateTime? now]) {
    final due = dueDate;
    if (due == null) return null;
    final today = _dateOnly(now ?? DateTime.now());
    return _dateOnly(due).difference(today).inDays;
  }

  /// 기존 호출부 호환용. 새 코드는 [daysUntilDue]를 사용한다.
  int? get daysUntilNext => daysUntilDue();

  bool get isOverdue {
    final days = daysUntilDue();
    return days != null && days < 0 && status != HealthRecordStatus.cancelled;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  HealthRecord copyWith({
    String? id,
    String? petId,
    String? userId,
    HealthRecordType? recordType,
    String? title,
    Object? description = _notProvided,
    DateTime? recordDate,
    Object? nextDate = _notProvided,
    HealthRecordStatus? status,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      userId: userId ?? this.userId,
      recordType: recordType ?? this.recordType,
      title: title ?? this.title,
      description: identical(description, _notProvided)
          ? this.description
          : description as String?,
      recordDate: recordDate ?? this.recordDate,
      nextDate: identical(nextDate, _notProvided)
          ? this.nextDate
          : nextDate as DateTime?,
      status: status ?? this.status,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        petId,
        userId,
        recordType,
        title,
        description,
        recordDate,
        nextDate,
        status,
        data,
        createdAt,
        updatedAt,
      ];
}

enum HealthRecordType { vaccination, checkup, weight, medication, surgery }

enum HealthRecordStatus { scheduled, completed, overdue, cancelled }
