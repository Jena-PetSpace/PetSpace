import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/health/domain/entities/health_record.dart';
import 'package:meong_nyang_diary/features/health/presentation/widgets/weight_trend.dart';

HealthRecord _weight(DateTime date, double? kg, {int? bcs}) => HealthRecord(
      id: date.toIso8601String(),
      petId: 'p',
      userId: 'u',
      recordType: HealthRecordType.weight,
      title: '체중',
      recordDate: date,
      status: HealthRecordStatus.completed,
      data: {
        if (kg != null) 'weight_kg': kg,
        if (bcs != null) 'bcs': bcs,
      },
      createdAt: date,
      updatedAt: date,
    );

HealthRecord _other(DateTime date) => HealthRecord(
      id: 'o-${date.day}',
      petId: 'p',
      userId: 'u',
      recordType: HealthRecordType.medication,
      title: '약',
      recordDate: date,
      status: HealthRecordStatus.completed,
      data: const {'med_name': '약'},
      createdAt: date,
      updatedAt: date,
    );

void main() {
  // ── 포인트 변환 ────────────────────────────────────────────────────────────
  group('buildWeightTrendPoints', () {
    test('빈 → 빈', () => expect(buildWeightTrendPoints(const []), isEmpty));

    test('weight 타입만 추출 + 날짜 오름차순', () {
      final pts = buildWeightTrendPoints([
        _weight(DateTime(2026, 6, 12), 5.4),
        _other(DateTime(2026, 6, 11)), // 제외
        _weight(DateTime(2026, 6, 10), 5.2),
      ]);
      expect(pts.length, 2);
      expect(pts.map((p) => p.weightKg), [5.2, 5.4]);
    });

    test('weight_kg 없는 기록은 제외', () {
      final pts = buildWeightTrendPoints([_weight(DateTime(2026, 6, 10), null)]);
      expect(pts, isEmpty);
    });

    test('bcs 보조값 보존', () {
      final pts =
          buildWeightTrendPoints([_weight(DateTime(2026, 6, 10), 5.2, bcs: 5)]);
      expect(pts.first.bcs, 5);
    });
  });

  // ── 증감 계산 ──────────────────────────────────────────────────────────────
  group('computeWeightDelta', () {
    List<WeightTrendPoint> pts(List<double> ws) => [
          for (var i = 0; i < ws.length; i++)
            WeightTrendPoint(recordDate: DateTime(2026, 6, 10 + i), weightKg: ws[i]),
        ];

    test('1건 → null (증감 불가)', () {
      expect(computeWeightDelta(pts([5.0])), null);
    });

    test('증가: 5.0 → 5.5 → +0.5kg, +10%', () {
      final d = computeWeightDelta(pts([5.0, 5.5]))!;
      expect(d.deltaKg, closeTo(0.5, 1e-9));
      expect(d.percent, closeTo(10.0, 1e-9));
      expect(d.isIncrease, true);
    });

    test('감소: 5.0 → 4.0 → -1.0kg, -20%', () {
      final d = computeWeightDelta(pts([5.0, 4.0]))!;
      expect(d.deltaKg, closeTo(-1.0, 1e-9));
      expect(d.percent, closeTo(-20.0, 1e-9));
      expect(d.isDecrease, true);
    });

    test('동일 → 0, flat', () {
      final d = computeWeightDelta(pts([5.0, 5.0]))!;
      expect(d.isFlat, true);
      expect(d.percent, 0);
    });

    test('다건이면 최신 2개 기준', () {
      final d = computeWeightDelta(pts([5.0, 6.0, 6.3]))!;
      expect(d.deltaKg, closeTo(0.3, 1e-9)); // 6.3 - 6.0
    });
  });

  // ── y축 범위 ──────────────────────────────────────────────────────────────
  group('weightAxisRange', () {
    test('값 범위에 패딩(0부터 아님)', () {
      final pts = [
        WeightTrendPoint(recordDate: DateTime(2026, 6, 10), weightKg: 5.0),
        WeightTrendPoint(recordDate: DateTime(2026, 6, 11), weightKg: 6.0),
      ];
      final r = weightAxisRange(pts);
      expect(r.min, lessThan(5.0)); // 0이 아니라 5 아래
      expect(r.max, greaterThan(6.0));
      expect(r.min, greaterThan(0)); // 5kg대는 0부터 시작 안 함
    });

    test('변화 작아도 최소 패딩 0.5kg 보장', () {
      final pts = [
        WeightTrendPoint(recordDate: DateTime(2026, 6, 10), weightKg: 5.0),
        WeightTrendPoint(recordDate: DateTime(2026, 6, 11), weightKg: 5.05),
      ];
      final r = weightAxisRange(pts);
      expect(r.max - r.min, greaterThanOrEqualTo(1.0)); // 양쪽 0.5씩
    });
  });
}
