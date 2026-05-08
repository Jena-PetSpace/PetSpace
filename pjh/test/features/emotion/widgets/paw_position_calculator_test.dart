import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/painters/paw_position_calculator.dart';

void main() {
  group('PawPositionCalculator.calculatePawPositions', () {
    test('returns 15 positions by default', () {
      final positions = PawPositionCalculator.calculatePawPositions();
      expect(positions.length, 15);
    });

    test('first position pins to start anchor (right 5%, top 50%)', () {
      final positions = PawPositionCalculator.calculatePawPositions();
      expect(positions.first.dx, closeTo(5.0, 1e-9));
      expect(positions.first.dy, closeTo(50.0, 1e-9));
    });

    test('last position pins to end anchor (right 50%, top 5%)', () {
      final positions = PawPositionCalculator.calculatePawPositions();
      expect(positions.last.dx, closeTo(50.0, 1e-9));
      expect(positions.last.dy, closeTo(5.0, 1e-9));
    });

    test('intermediate positions deviate from straight line', () {
      final positions = PawPositionCalculator.calculatePawPositions();
      bool anyDeviates = false;
      for (int i = 1; i < positions.length - 1; i++) {
        final t = i / (positions.length - 1);
        final straightTop = 50.0 - 45.0 * t;
        final straightRight = 5.0 + 45.0 * t;
        if ((positions[i].dy - straightTop).abs() > 0.5 ||
            (positions[i].dx - straightRight).abs() > 0.5) {
          anyDeviates = true;
          break;
        }
      }
      expect(anyDeviates, isTrue);
    });

    test('right coordinate trends upward across the trail', () {
      final positions = PawPositionCalculator.calculatePawPositions();
      expect(positions.last.dx, greaterThan(positions.first.dx));
    });

    test('top coordinate trends downward (toward 0) across the trail', () {
      final positions = PawPositionCalculator.calculatePawPositions();
      expect(positions.last.dy, lessThan(positions.first.dy));
    });

    test('zero amplitude produces a straight line', () {
      final positions =
          PawPositionCalculator.calculatePawPositions(amplitude: 0.0);
      for (int i = 0; i < positions.length; i++) {
        final t = i / (positions.length - 1);
        expect(positions[i].dy, closeTo(50.0 - 45.0 * t, 1e-9));
        expect(positions[i].dx, closeTo(5.0 + 45.0 * t, 1e-9));
      }
    });

    test('custom count is honored', () {
      final positions =
          PawPositionCalculator.calculatePawPositions(count: 6);
      expect(positions.length, 6);
      expect(positions.first.dx, closeTo(5.0, 1e-9));
      expect(positions.first.dy, closeTo(50.0, 1e-9));
      expect(positions.last.dx, closeTo(50.0, 1e-9));
      expect(positions.last.dy, closeTo(5.0, 1e-9));
    });
  });
}
