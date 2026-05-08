import 'dart:math' as math;
import 'dart:ui' show Offset;

/// 발자국 좌표 계산 — 화면 우측 하단(시작점)에서 좌측 상단(도착점)까지
/// 사인 곡선을 따라 발자국을 균등 배치한다.
///
/// 좌표는 % 단위 (0~100). [Offset.dx]는 right%, [Offset.dy]는 top%.
/// AI 로딩 화면 스펙 v1.0 §3.2 참조.
class PawPositionCalculator {
  static const int kPawCount = 15;
  static const double kPawAmp = 3.0;
  static const double kPerpFactor = 0.7071067811865476;

  /// 사족보행: 중앙선 좌우로 두 줄을 벌릴 때 각 줄의 perpendicular 오프셋.
  /// 두 줄 사이 폭 = 2 * kPairOffset (% 단위).
  static const double kPairOffset = 2.5;

  static const double _startTopPct = 50.0;
  static const double _startRightPct = 5.0;
  static const double _endTopPct = 5.0;
  static const double _endRightPct = 50.0;

  static const double _waveCycles = 1.5;

  const PawPositionCalculator._();

  /// 단일 줄(중앙선) 좌표 — 12개 발자국을 곡선을 따라 배치.
  /// 시작·도착점은 wave=0으로 정확히 고정된다.
  static List<Offset> calculatePawPositions({
    int count = kPawCount,
    double amplitude = kPawAmp,
  }) {
    return _calculate(count: count, amplitude: amplitude, sideOffset: 0.0);
  }

  /// 두 줄(사족보행) 좌표 — 좌측줄과 우측줄을 분리해서 반환.
  /// 트레일 진행 방향(우하 → 좌상)에 대해 perpendicular로 ±sideOffset 만큼 벌어진다.
  static PawTrailPair calculatePawPairPositions({
    int count = kPawCount,
    double amplitude = kPawAmp,
    double sideOffset = kPairOffset,
  }) {
    final left = _calculate(
      count: count,
      amplitude: amplitude,
      sideOffset: sideOffset,
    );
    final right = _calculate(
      count: count,
      amplitude: amplitude,
      sideOffset: -sideOffset,
    );
    return PawTrailPair(left: left, right: right);
  }

  /// 트레일 진행 방향 단위 벡터 (우하→좌상).
  /// dx = endRight - startRight = +45, dy = endTop - startTop = -45.
  /// 정규화 후 perpendicular 단위 벡터(왼쪽 방향)는 (-1, -1) * (1/√2) 부호.
  /// 여기서는 perpendicular를 (right, top) 좌표계 기준 (-1/√2, -1/√2) 로 잡는다
  /// — 이 방향이 트레일을 바라봤을 때 "왼쪽"에 해당.
  static List<Offset> _calculate({
    required int count,
    required double amplitude,
    required double sideOffset,
  }) {
    final positions = <Offset>[];
    final perpRight = -kPerpFactor * sideOffset;
    final perpTop = -kPerpFactor * sideOffset;

    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final wave = math.sin(t * _waveCycles * 2 * math.pi) * amplitude;
      final top = _startTopPct -
          (_startTopPct - _endTopPct) * t -
          wave * kPerpFactor +
          perpTop;
      final right = _startRightPct +
          (_endRightPct - _startRightPct) * t -
          wave * kPerpFactor +
          perpRight;
      positions.add(Offset(right, top));
    }
    return positions;
  }
}

/// 사족보행 두 줄 좌표 묶음.
class PawTrailPair {
  final List<Offset> left;
  final List<Offset> right;
  const PawTrailPair({required this.left, required this.right});
}
