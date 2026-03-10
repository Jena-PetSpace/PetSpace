import 'package:equatable/equatable.dart';

class HealthRecord extends Equatable {
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

  int? get daysUntilNext {
    if (nextDate == null) return null;
    return nextDate!.difference(DateTime.now()).inDays;
  }

  bool get isOverdue =>
      status == HealthRecordStatus.scheduled &&
      recordDate.isBefore(DateTime.now());

  HealthRecord copyWith({
    String? id,
    String? petId,
    String? userId,
    HealthRecordType? recordType,
    String? title,
    String? description,
    DateTime? recordDate,
    DateTime? nextDate,
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
      description: description ?? this.description,
      recordDate: recordDate ?? this.recordDate,
      nextDate: nextDate ?? this.nextDate,
      status: status ?? this.status,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, petId, recordType, title, recordDate, status];
}

enum HealthRecordType { vaccination, checkup, weight, medication, surgery }

enum HealthRecordStatus { scheduled, completed, overdue, cancelled }
