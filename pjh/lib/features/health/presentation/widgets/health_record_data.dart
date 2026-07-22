import '../../domain/entities/health_record.dart';

/// 투약 반복 주기 선택지.
const List<String> medicationFrequencies = ['매일', '주 2회', '주 3회', '1회'];

/// 타입별 전용 입력값 → HealthRecord.data Map 구성(순수 함수, 테스트 대상).
/// null/빈 값은 키를 넣지 않아 깔끔한 JSON을 만든다.
Map<String, dynamic> buildHealthRecordData({
  required HealthRecordType type,
  double? weightKg,
  int? bcs,
  String? vaccineType,
  String? hospital,
  String? medName,
  String? dosage,
  String? frequency,
  DateTime? endDate,
  String? result,
  int? cost,
  String? surgeryName,
}) {
  final data = <String, dynamic>{};
  void put(String k, dynamic v) {
    if (v == null) return;
    if (v is String && v.trim().isEmpty) return;
    data[k] = v is String ? v.trim() : v;
  }

  switch (type) {
    case HealthRecordType.weight:
      put('weight_kg', weightKg);
      put('bcs', bcs);
      break;
    case HealthRecordType.vaccination:
      put('vaccine_type', vaccineType);
      put('hospital', hospital);
      break;
    case HealthRecordType.medication:
      put('med_name', medName);
      put('dosage', dosage);
      put('frequency', frequency);
      put('end_date', endDate?.toIso8601String());
      break;
    case HealthRecordType.checkup:
      put('hospital', hospital);
      put('result', result);
      put('cost', cost);
      break;
    case HealthRecordType.surgery:
      put('surgery_name', surgeryName);
      put('hospital', hospital);
      break;
  }
  return data;
}

/// 체중 입력 문자열 → kg double 파싱(소수 허용). 유효하지 않으면 null.
double? parseWeightKg(String raw) {
  final v = double.tryParse(raw.trim());
  if (v == null || v <= 0) return null;
  return v;
}

/// 비용 입력 문자열 → 정수원. 비거나 유효하지 않으면 null.
int? parseCost(String raw) {
  final cleaned = raw.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  final value = int.tryParse(cleaned);
  return value != null && value >= 0 ? value : null;
}

/// 체중 기록 자동 제목("체중 5.2kg"). 그 외 타입은 사용자 title 유지.
String weightTitle(double weightKg) {
  // 소수점 불필요한 정수면 정수로 표기
  final s = weightKg == weightKg.roundToDouble()
      ? weightKg.toInt().toString()
      : weightKg.toString();
  return '체중 ${s}kg';
}

/// 최근 기록 카드의 첫 줄. 사용자가 저장한 이름을 우선하고, 오래된 빈 제목은
/// 구조화 데이터 또는 기록 유형으로 안전하게 보완한다.
String recordCardDisplayTitle(HealthRecord record) {
  if (record.title.trim().isNotEmpty) return record.title.trim();
  final data = record.data;
  final structured = switch (record.recordType) {
    HealthRecordType.vaccination => data['vaccine_type'],
    HealthRecordType.checkup => null,
    HealthRecordType.weight => data['weight_kg'],
    HealthRecordType.medication => data['med_name'],
    HealthRecordType.surgery => data['surgery_name'],
  };
  if (record.recordType == HealthRecordType.weight && structured is num) {
    return weightTitle(structured.toDouble());
  }
  if (structured is String && structured.trim().isNotEmpty) {
    return structured.trim();
  }
  return switch (record.recordType) {
    HealthRecordType.vaccination => '예방접종',
    HealthRecordType.checkup => '건강검진',
    HealthRecordType.weight => '체중 기록',
    HealthRecordType.medication => '투약 기록',
    HealthRecordType.surgery => '수술 기록',
  };
}

/// 첫 줄과 중복되지 않는 최근 기록 카드의 보조 정보.
String recordCardDetail(HealthRecord record) {
  final data = record.data;
  String optionalDescription() => record.description?.trim().isNotEmpty == true
      ? record.description!.trim()
      : '세부 내용 없음';

  switch (record.recordType) {
    case HealthRecordType.weight:
      final bcs = data['bcs'];
      return bcs is num ? 'BCS ${bcs.toInt()}' : optionalDescription();
    case HealthRecordType.vaccination:
      final hospital = data['hospital'];
      return hospital is String && hospital.trim().isNotEmpty
          ? hospital.trim()
          : optionalDescription();
    case HealthRecordType.checkup:
      final parts = <String>[
        if (data['hospital'] is String &&
            (data['hospital'] as String).trim().isNotEmpty)
          (data['hospital'] as String).trim(),
        if (data['result'] is String &&
            (data['result'] as String).trim().isNotEmpty)
          (data['result'] as String).trim(),
      ];
      return parts.isEmpty ? optionalDescription() : parts.join(' · ');
    case HealthRecordType.medication:
      final parts = <String>[
        if (data['dosage'] is String &&
            (data['dosage'] as String).trim().isNotEmpty)
          (data['dosage'] as String).trim(),
        if (data['frequency'] is String &&
            (data['frequency'] as String).trim().isNotEmpty)
          (data['frequency'] as String).trim(),
      ];
      return parts.isEmpty ? optionalDescription() : parts.join(' · ');
    case HealthRecordType.surgery:
      final hospital = data['hospital'];
      return hospital is String && hospital.trim().isNotEmpty
          ? hospital.trim()
          : optionalDescription();
  }
}

/// 카드 부제 — record.data에서 타입별 핵심 정보를 뽑는다.
/// data가 비었거나(기존 레코드 전부 {}) 키가 없으면 title/description로 fallback(하위호환).
String recordCardSubtitle(HealthRecord record) {
  final d = record.data;

  String fallback() {
    if (record.title.trim().isNotEmpty) return record.title.trim();
    return record.description?.trim().isNotEmpty == true
        ? record.description!.trim()
        : '-';
  }

  switch (record.recordType) {
    case HealthRecordType.weight:
      final w = d['weight_kg'];
      if (w is num) {
        final bcs = d['bcs'];
        final base = '${w}kg';
        return bcs is num ? '$base · BCS $bcs' : base;
      }
      return fallback();
    case HealthRecordType.medication:
      final name = d['med_name'];
      if (name is String && name.trim().isNotEmpty) {
        final parts = <String>[name.trim()];
        final dosage = d['dosage'];
        final freq = d['frequency'];
        final detail = [
          if (dosage is String && dosage.trim().isNotEmpty) dosage.trim(),
          if (freq is String && freq.trim().isNotEmpty) freq.trim(),
        ].join('/');
        if (detail.isNotEmpty) parts.add(detail);
        return parts.join(' ');
      }
      return fallback();
    case HealthRecordType.vaccination:
      final type = d['vaccine_type'];
      if (type is String && type.trim().isNotEmpty) {
        final hospital = d['hospital'];
        return hospital is String && hospital.trim().isNotEmpty
            ? '${type.trim()} · ${hospital.trim()}'
            : type.trim();
      }
      return fallback();
    case HealthRecordType.checkup:
      final hospital = d['hospital'];
      final result = d['result'];
      final parts = [
        if (hospital is String && hospital.trim().isNotEmpty) hospital.trim(),
        if (result is String && result.trim().isNotEmpty) result.trim(),
      ];
      return parts.isNotEmpty ? parts.join(' · ') : fallback();
    case HealthRecordType.surgery:
      final name = d['surgery_name'];
      if (name is String && name.trim().isNotEmpty) {
        final hospital = d['hospital'];
        return hospital is String && hospital.trim().isNotEmpty
            ? '${name.trim()} · ${hospital.trim()}'
            : name.trim();
      }
      return fallback();
  }
}
