import 'dart:math';
import 'package:flutter/material.dart';

/// 유기적 모핑 블롭 CustomPainter
class BlobPainter extends CustomPainter {
  final double animationValue;
  final Color color1;
  final Color color2;
  final double opacity;

  BlobPainter({
    required this.animationValue,
    required this.color1,
    required this.color2,
    this.opacity = 0.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.35;
    final time = animationValue * 2 * pi;

    final path = Path();
    const pointCount = 6;
    final points = <Offset>[];

    for (int i = 0; i < pointCount; i++) {
      final angle = (i / pointCount) * 2 * pi;
      final wobble =
          sin(time + i * 1.5) * 12 + cos(time * 0.7 + i * 0.8) * 8;
      final r = baseRadius + wobble;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      points.add(Offset(x, y));
    }

    // 부드러운 곡선을 위해 cubic bezier 사용
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < pointCount; i++) {
      final p0 = points[i];
      final p1 = points[(i + 1) % pointCount];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color1.withValues(alpha: opacity),
          color2.withValues(alpha: opacity),
        ],
      ).createShader(
        Rect.fromCenter(
          center: center,
          width: size.width,
          height: size.height,
        ),
      )
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BlobPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.color1 != color1 ||
      oldDelegate.color2 != color2;
}

/// 원형 프로그레스 링 CustomPainter
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 배경 링
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // 프로그레스 링
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      progress * 2 * pi,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
