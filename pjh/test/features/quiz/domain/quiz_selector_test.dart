import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/quiz/domain/services/quiz_selector.dart';

void main() {
  // 실제 콘텐츠와 동일한 규모로 검증.
  const selector = QuizSelector(total: 270, dailyCount: 4);

  group('permutation — 결정적 셔플', () {
    test('같은 시드 → 동일 순열', () {
      expect(selector.permutation(123), selector.permutation(123));
    });

    test('다른 시드 → 보통 다른 순열', () {
      expect(selector.permutation(1), isNot(equals(selector.permutation(2))));
    });

    test('순열은 0..269 의 완전순열(누락·중복 없음)', () {
      final perm = selector.permutation(987654);
      expect(perm.length, 270);
      expect(perm.toSet().length, 270); // 중복 없음
      expect(perm.toSet(), List.generate(270, (i) => i).toSet()); // 누락 없음
    });

    test('여러 시드 모두 완전순열', () {
      for (final seed in [1, 2, 7, 100, 99999, 0x7FFFFFFF]) {
        final perm = selector.permutation(seed);
        expect(perm.toSet().length, 270, reason: 'seed=$seed');
      }
    });
  });

  group('setIndicesAt — 오늘 세트', () {
    test('커서 0 → 순열 앞 dailyCount개', () {
      final perm = selector.permutation(555);
      final set = selector.setIndicesAt(555, 0);
      expect(set, perm.sublist(0, 4));
    });

    test('커서 전진 시 다음 구간', () {
      final perm = selector.permutation(555);
      expect(selector.setIndicesAt(555, 4), perm.sublist(4, 8));
      expect(selector.setIndicesAt(555, 8), perm.sublist(8, 12));
    });

    test('항상 dailyCount(=4)개 (바퀴 끝 직전까지)', () {
      for (int cursor = 0; cursor + 4 <= 270; cursor += 4) {
        expect(selector.setIndicesAt(555, cursor).length, 4,
            reason: 'cursor=$cursor');
      }
    });
  });

  group('바퀴 내 무중복 — 270 다 돌기 전 중복 0', () {
    test('커서 0→270 까지 끊어 모은 문항이 270개 전부 정확히 1번씩', () {
      const seed = 314159;
      final perm = selector.permutation(seed);
      final collected = <int>[];
      int cursor = 0;
      while (cursor < 270) {
        final set = selector.indicesFromPermutation(perm, cursor);
        collected.addAll(set);
        cursor += set.length;
      }
      expect(collected.length, 270);
      expect(collected.toSet().length, 270); // 무중복
      expect(cursor, 270);
    });

    test('270÷4=67.5 → 마지막 세트는 잔여 2문항', () {
      // 마지막 세트 시작 커서 = 268 (67세트×4) → 남은 2개.
      final last = selector.setIndicesAt(7, 268);
      expect(last.length, 2);
      // 그 앞 세트(264)는 4개.
      expect(selector.setIndicesAt(7, 264).length, 4);
    });
  });

  group('reshuffleSeed — 바퀴 경계 보정', () {
    test('새 시드는 직전 시드와 다른 순열을 만든다', () {
      const prev = 111;
      final next = selector.reshuffleSeed(prev);
      expect(selector.permutation(next),
          isNot(equals(selector.permutation(prev))));
    });

    test('직전 바퀴 마지막 세트(잔여 2문항)가 새 바퀴 첫 세트에 안 겹침', () {
      const prev = 24680;
      final prevPerm = selector.permutation(prev);
      // 마지막 세트 = 잔여(268..269) 2문항.
      final prevTail = prevPerm.sublist(268).toSet();

      final next = selector.reshuffleSeed(prev);
      final newHead = selector.permutation(next).take(4).toSet();

      expect(newHead.intersection(prevTail), isEmpty);
    });

    test('여러 시드에서 경계 보정이 성립', () {
      for (final prev in [1, 42, 1000, 555555]) {
        final prevTail = selector.permutation(prev).sublist(268).toSet();
        final next = selector.reshuffleSeed(prev);
        final head = selector.permutation(next).take(4).toSet();
        expect(head.intersection(prevTail), isEmpty, reason: 'prev=$prev');
      }
    });

    test('재셔플 시드는 결정적(같은 prev → 같은 next)', () {
      expect(selector.reshuffleSeed(99), selector.reshuffleSeed(99));
    });
  });

  group('나누어떨어지는 경우 경계 처리', () {
    // total 이 dailyCount 배수면 마지막 세트가 꽉 찬 dailyCount개.
    const even = QuizSelector(total: 20, dailyCount: 4);

    test('마지막 세트도 4개', () {
      expect(even.setIndicesAt(3, 16).length, 4);
    });

    test('경계 보정: 마지막 4문항이 새 바퀴 앞 4에 안 겹침', () {
      final prevTail = even.permutation(3).sublist(16).toSet();
      final next = even.reshuffleSeed(3);
      final head = even.permutation(next).take(4).toSet();
      expect(head.intersection(prevTail), isEmpty);
    });
  });
}
