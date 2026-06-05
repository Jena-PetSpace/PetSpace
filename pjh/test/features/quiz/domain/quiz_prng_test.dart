import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/quiz/domain/services/quiz_prng.dart';

void main() {
  group('QuizPrng — 결정성', () {
    test('같은 시드 → 같은 수열', () {
      final a = QuizPrng(12345);
      final b = QuizPrng(12345);
      for (int i = 0; i < 100; i++) {
        expect(a.nextInt(1000), b.nextInt(1000));
      }
    });

    test('다른 시드 → 보통 다른 수열', () {
      final a = QuizPrng(1);
      final b = QuizPrng(2);
      final seqA = List.generate(20, (_) => a.nextInt(1 << 20));
      final seqB = List.generate(20, (_) => b.nextInt(1 << 20));
      expect(seqA, isNot(equals(seqB)));
    });
  });

  group('QuizPrng — 범위·균등', () {
    test('nextInt(bound) 는 0..bound-1 범위', () {
      final rng = QuizPrng(777);
      for (int i = 0; i < 5000; i++) {
        final v = rng.nextInt(7);
        expect(v >= 0 && v < 7, isTrue);
      }
    });

    test('nextInt(1) 은 항상 0', () {
      final rng = QuizPrng(42);
      for (int i = 0; i < 50; i++) {
        expect(rng.nextInt(1), 0);
      }
    });

    test('대략 균등 분포(편향 과도하지 않음)', () {
      final rng = QuizPrng(2026);
      const bound = 10;
      const n = 100000;
      final counts = List<int>.filled(bound, 0);
      for (int i = 0; i < n; i++) {
        counts[rng.nextInt(bound)]++;
      }
      const expected = n / bound;
      for (final c in counts) {
        // 각 버킷이 기대치의 ±10% 안(거부표집 modulo 편향 제거 확인).
        expect((c - expected).abs() < expected * 0.1, isTrue,
            reason: 'counts=$counts');
      }
    });
  });
}
