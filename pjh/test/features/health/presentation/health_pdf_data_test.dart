import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';
import 'package:meong_nyang_diary/features/health/presentation/widgets/health_pdf_data.dart';

HealthRecord _r(
  HealthRecordType type,
  DateTime date, {
  Map<String, dynamic> data = const {},
  String title = '제목',
  DateTime? next,
}) =>
    HealthRecord(
      id: '${type.name}-${date.day}',
      petId: 'p',
      userId: 'u',
      recordType: type,
      title: title,
      recordDate: date,
      nextDate: next,
      status: HealthRecordStatus.completed,
      data: data,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  group('buildHealthPdfData', () {
    test('빈 리스트 → 모든 섹션 비고 hasAny=false', () {
      final d = buildHealthPdfData(const []);
      expect(d.weights, isEmpty);
      expect(d.vaccinations, isEmpty);
      expect(d.medications, isEmpty);
      expect(d.exams, isEmpty);
      expect(d.hasAny, false);
    });

    test('타입별 분류 — 체중/접종/투약/검진/수술', () {
      final d = buildHealthPdfData([
        _r(HealthRecordType.weight, DateTime(2026, 6, 10),
            data: {'weight_kg': 5.0}),
        _r(HealthRecordType.weight, DateTime(2026, 6, 12),
            data: {'weight_kg': 5.4}),
        _r(HealthRecordType.vaccination, DateTime(2026, 6, 1),
            data: {'vaccine_type': '종합백신'}, next: DateTime(2027, 6, 1)),
        _r(HealthRecordType.medication, DateTime(2026, 6, 5),
            data: {'med_name': '심장약', 'dosage': '5mg', 'frequency': '매일'}),
        _r(HealthRecordType.checkup, DateTime(2026, 6, 8),
            data: {'hospital': 'A병원', 'result': '정상'}),
        _r(HealthRecordType.surgery, DateTime(2026, 6, 9),
            data: {'surgery_name': '중성화', 'hospital': 'B병원'}),
      ]);

      expect(d.weights.length, 2);
      expect(d.weightDelta, isNotNull); // 2건 → 증감 있음
      expect(d.vaccinations.single['vaccine_type'], '종합백신');
      expect(d.vaccinations.single['next'], '2027.06.01');
      expect(d.medications.single['med_name'], '심장약');
      expect(d.medications.single['frequency'], '매일');
      // 검진+수술 = exams 2건
      expect(d.exams.length, 2);
      expect(d.exams.map((e) => e['kind']).toSet(), {'검진', '수술'});
      expect(d.hasAny, true);
    });

    test('빈 섹션은 빈 리스트(나열 안 함)', () {
      final d = buildHealthPdfData([
        _r(HealthRecordType.weight, DateTime(2026, 6, 10),
            data: {'weight_kg': 5.0}),
      ]);
      expect(d.weights.length, 1);
      expect(d.weightDelta, isNull); // 1건 → 증감 없음
      expect(d.vaccinations, isEmpty);
      expect(d.medications, isEmpty);
      expect(d.exams, isEmpty);
      expect(d.hasAny, true);
    });

    test('data 없는 기록도 title fallback', () {
      final d = buildHealthPdfData([
        _r(HealthRecordType.medication, DateTime(2026, 6, 5),
            data: const {}, title: '구충제'),
      ]);
      expect(d.medications.single['med_name'], '구충제');
    });

    test('exams 최신순 정렬', () {
      final d = buildHealthPdfData([
        _r(HealthRecordType.checkup, DateTime(2026, 6, 1),
            data: {'hospital': '옛날'}),
        _r(HealthRecordType.checkup, DateTime(2026, 6, 20),
            data: {'hospital': '최근'}),
      ]);
      expect(d.exams.first['hospital'], '최근');
    });
  });
}
