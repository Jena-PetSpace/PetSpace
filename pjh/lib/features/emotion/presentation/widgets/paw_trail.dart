import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'painters/paw_position_calculator.dart';

/// 흰 발자국이 사인 곡선을 따라 화면 우측 하단 → 좌측 상단으로 흘러가는 트레일.
///
/// ## 사이클 동작 (Cycle 모델)
/// 1. **Write**: 우하단부터 [stagger] 간격으로 한 발씩 등장. N개 모두 찍힐 때까지.
/// 2. **Hold**: N개가 모두 표시된 채 [holdDuration] 동안 유지.
/// 3. **Clear**: 전체가 [fadeOutSeconds] 동안 함께 fade out.
/// 4. 다시 phase 1로 반복.
///
/// 각 발자국은 등장 시 [fadeInSeconds] 동안 페이드 인, 사이클 종료 시 함께 페이드 아웃.
///
/// [quadruped]가 true면 두 줄로 배치되며, 우측 줄은 절반 stagger만큼 앞서 찍힌다.
class PawTrail extends StatefulWidget {
  final Duration stagger;
  final Duration holdDuration;
  final double fadeInSeconds;
  final double fadeOutSeconds;
  final double pawSizeDp;
  final double rotationDegrees;
  final double maxOpacity;
  final Color color;
  final bool quadruped;

  const PawTrail({
    super.key,
    this.stagger = const Duration(milliseconds: 444),
    this.holdDuration = const Duration(milliseconds: 1000),
    this.fadeInSeconds = 0.4,
    this.fadeOutSeconds = 0.4,
    this.pawSizeDp = 18.4,
    this.rotationDegrees = -30.0,
    this.maxOpacity = 0.9,
    this.color = Colors.white,
    this.quadruped = true,
  });

  @override
  State<PawTrail> createState() => _PawTrailState();
}

class _PawTrailState extends State<PawTrail>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<Offset> _leftPositions;
  late final List<Offset> _rightPositions;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.quadruped) {
      final pair = PawPositionCalculator.calculatePawPairPositions();
      _leftPositions = pair.left;
      _rightPositions = pair.right;
    } else {
      _leftPositions = PawPositionCalculator.calculatePawPositions();
      _rightPositions = const [];
    }
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _elapsed = elapsed;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// 사이클 길이 (초). write + hold + clear.
  double get _cycleSeconds {
    final stagger = widget.stagger.inMilliseconds / 1000.0;
    final hold = widget.holdDuration.inMilliseconds / 1000.0;
    return _leftPositions.length * stagger +
        widget.fadeInSeconds + // 마지막 발자국 fade in 끝나야 hold 시작
        hold +
        widget.fadeOutSeconds;
  }

  /// 발자국 i (0..N-1)의 사이클 내 opacity.
  ///
  /// - birth = i * stagger (+ laneOffset)
  /// - 모든 발자국 등장 완료 시점 = (N-1)*stagger + fadeIn
  /// - 그 후 hold 동안 maxOpacity 유지
  /// - clear 단계에서 일제히 fade out
  double _opacityFor(int i, int n,
      {required double cycleSec, required double laneOffsetSec}) {
    final stagger = widget.stagger.inMilliseconds / 1000.0;
    final hold = widget.holdDuration.inMilliseconds / 1000.0;
    final birth = i * stagger + laneOffsetSec;
    final fadeInDone = birth + widget.fadeInSeconds;
    final lastBirth = (n - 1) * stagger; // laneOffset 무시 — 가장 마지막 등장
    final clearStart = lastBirth + widget.fadeInSeconds + hold;
    final clearEnd = clearStart + widget.fadeOutSeconds;

    if (cycleSec < birth) return 0.0;
    if (cycleSec >= clearEnd) return 0.0;

    // fade in
    if (cycleSec < fadeInDone) {
      final p = (cycleSec - birth) / widget.fadeInSeconds;
      return p.clamp(0.0, 1.0) * widget.maxOpacity;
    }
    // hold
    if (cycleSec < clearStart) {
      return widget.maxOpacity;
    }
    // fade out (전체 동시)
    final p = (cycleSec - clearStart) / widget.fadeOutSeconds;
    return (1.0 - p).clamp(0.0, 1.0) * widget.maxOpacity;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildContent(constraints.maxWidth, constraints.maxHeight);
      },
    );
  }

  Widget _buildContent(double w, double h) {
    final n = _leftPositions.length;
    if (n == 0) return const SizedBox.shrink();

    final stagger = widget.stagger.inMilliseconds / 1000.0;
    final cycle = _cycleSeconds;
    final elapsedSec = _elapsed.inMicroseconds / 1e6;
    final cycleSec = elapsedSec % cycle;

    final children = <Widget>[];
    for (int i = 0; i < n; i++) {
      final leftOpacity =
          _opacityFor(i, n, cycleSec: cycleSec, laneOffsetSec: 0.0);
      if (leftOpacity > 0.0) {
        children.add(_buildPaw(_leftPositions[i], leftOpacity, w, h,
            keyTag: 'L$i'));
      }
      if (_rightPositions.isNotEmpty) {
        final rightOpacity = _opacityFor(i, n,
            cycleSec: cycleSec, laneOffsetSec: -stagger / 2.0);
        if (rightOpacity > 0.0) {
          children.add(_buildPaw(_rightPositions[i], rightOpacity, w, h,
              keyTag: 'R$i'));
        }
      }
    }
    return Stack(children: children);
  }

  Widget _buildPaw(Offset pos, double opacity, double w, double h,
      {required String keyTag}) {
    final right = (pos.dx / 100.0) * w;
    final top = (pos.dy / 100.0) * h;

    return Positioned(
      key: ValueKey(keyTag),
      right: right,
      top: top,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: widget.rotationDegrees * 3.1415926535 / 180.0,
          child: CustomPaint(
            size: Size(widget.pawSizeDp, widget.pawSizeDp),
            painter: _PawPainter(color: widget.color),
          ),
        ),
      ),
    );
  }
}

class _PawPainter extends CustomPainter {
  final Color color;
  const _PawPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final s = size.width / 20.0;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(10 * s, 13.5 * s),
        width: 10 * s,
        height: 7.4 * s,
      ),
      paint,
    );
    canvas.drawCircle(Offset(4.5 * s, 8 * s), 1.7 * s, paint);
    canvas.drawCircle(Offset(9 * s, 5 * s), 1.7 * s, paint);
    canvas.drawCircle(Offset(13.2 * s, 5 * s), 1.7 * s, paint);
    canvas.drawCircle(Offset(17 * s, 9 * s), 1.7 * s, paint);
  }

  @override
  bool shouldRepaint(covariant _PawPainter oldDelegate) =>
      oldDelegate.color != color;
}
