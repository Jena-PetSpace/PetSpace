import '../../domain/entities/health_record.dart';

class HealthRecordModel extends HealthRecord {
  const HealthRecordModel({
    required super.id,
    required super.petId,
    required super.userId,
    required super.recordType,
    required super.title,
    super.description,
    required super.recordDate,
    super.nextDate,
    required super.status,
    super.data,
    required super.createdAt,
    required super.updatedAt,
  });

  factory HealthRecordModel.fromJson(Map<String, dynamic> json) {
    return HealthRecordModel(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      userId: json['user_id'] as String,
      recordType: _parseRecordType(json['record_type'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      recordDate: DateTime.parse(json['record_date'] as String),
      nextDate: json['next_date'] != null
          ? DateTime.parse(json['next_date'] as String)
          : null,
      status: _parseStatus(json['status'] as String),
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pet_id': petId,
      'user_id': userId,
      'record_type': recordType.name,
      'title': title,
      'description': description,
      'record_date': recordDate.toIso8601String().split('T').first,
      'next_date': nextDate?.toIso8601String().split('T').first,
      'status': status.name,
      'data': data,
    };
  }

  factory HealthRecordModel.fromEntity(HealthRecord entity) {
    return HealthRecordModel(
      id: entity.id,
      petId: entity.petId,
      userId: entity.userId,
      recordType: entity.recordType,
      title: entity.title,
      description: entity.description,
      recordDate: entity.recordDate,
      nextDate: entity.nextDate,
      status: entity.status,
      data: entity.data,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  static HealthRecordType _parseRecordType(String type) {
    switch (type) {
      case 'vaccination':
        return HealthRecordType.vaccination;
      case 'checkup':
        return HealthRecordType.checkup;
      case 'weight':
        return HealthRecordType.weight;
      case 'medication':
        return HealthRecordType.medication;
      case 'surgery':
        return HealthRecordType.surgery;
      default:
        return HealthRecordType.checkup;
    }
  }

  static HealthRecordStatus _parseStatus(String status) {
    switch (status) {
      case 'scheduled':
        return HealthRecordStatus.scheduled;
      case 'completed':
        return HealthRecordStatus.completed;
      case 'overdue':
        return HealthRecordStatus.overdue;
      case 'cancelled':
        return HealthRecordStatus.cancelled;
      default:
        return HealthRecordStatus.scheduled;
    }
  }
}
