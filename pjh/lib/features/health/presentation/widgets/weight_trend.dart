import '../../domain/entities/health_record.dart';

/// 체중 추이 차트의 한 점(체중 기록 1건).
class WeightTrendPoint {
  final DateTime recordDate;
  final double weightKg;
  final int? bcs;

  const WeightTrendPoint({
    required this.recordDate,
    required this.weightKg,
    this.bcs,
  });
}

/// 전 측정 대비 증감.
class WeightDelta {
  final double deltaKg; // 최신 - 직전 (양수=증가)
  final double percent; // 직전 대비 % (양수=증가)

  const WeightDelta({required this.deltaKg, required this.percent});

  bool get isIncrease => deltaKg > 0;
  bool get isDecrease => deltaKg < 0;
  bool get isFlat => deltaKg == 0;
}

/// 건강기록 리스트 → 체중 추이 포인트(순수 함수, 테스트 대상).
/// - recordType==weight 이고 data['weight_kg']가 숫자인 기록만.
/// - recordDate 오름차순 정렬.
List<WeightTrendPoint> buildWeightTrendPoints(List<HealthRecord> records) {
  final points = <WeightTrendPoint>[];
  for (final r in records) {
    if (r.recordType != HealthRecordType.weight) continue;
    final w = r.data['weight_kg'];
    if (w is! num) continue;
    final b = r.data['bcs'];
    points.add(WeightTrendPoint(
      recordDate: r.recordDate,
      weightKg: w.toDouble(),
      bcs: b is num ? b.toInt() : null,
    ));
  }
  points.sort((a, b) => a.recordDate.compareTo(b.recordDate));
  return points;
}

/// 최신 vs 직전 체중 증감. 포인트 2개 미만이면 null(증감 계산 불가).
WeightDelta? computeWeightDelta(List<WeightTrendPoint> points) {
  if (points.length < 2) return null;
  final latest = points[points.length - 1].weightKg;
  final prev = points[points.length - 2].weightKg;
  final delta = latest - prev;
  final percent = prev == 0 ? 0.0 : (delta / prev) * 100;
  return WeightDelta(deltaKg: delta, percent: percent);
}

/// y축 범위(min, max) — 값 범위에 맞춰 여유 패딩. 0부터 시작하지 않아 작은 변화도 보이게.
/// 단 과장 방지를 위해 최소 패딩(0.5kg) 보장.
({double min, double max}) weightAxisRange(List<WeightTrendPoint> points) {
  if (points.isEmpty) return (min: 0, max: 1);
  double lo = points.first.weightKg;
  double hi = points.first.weightKg;
  for (final p in points) {
    if (p.weightKg < lo) lo = p.weightKg;
    if (p.weightKg > hi) hi = p.weightKg;
  }
  final span = hi - lo;
  // 패딩: 범위의 20%, 단 최소 0.5kg
  final pad = (span * 0.2).clamp(0.5, double.infinity);
  final min = (lo - pad).clamp(0.0, double.infinity).toDouble();
  return (min: min, max: hi + pad);
}
