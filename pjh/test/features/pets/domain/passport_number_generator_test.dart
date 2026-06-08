import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/pets/domain/services/passport_number_generator.dart';

void main() {
  group('PassportNumberGenerator.generate (형식)', () {
    test('형식: P + 영문 대문자 2 + 숫자 5 (총 8자)', () {
      final gen = PassportNumberGenerator(random: Random(42));
      for (var i = 0; i < 1000; i++) {
        final no = gen.generate();
        expect(no.length, 8, reason: '여권번호는 8자여야 함: $no');
        expect(PassportNumberGenerator.pattern.hasMatch(no), isTrue,
            reason: '형식 P[A-Z]{2}\\d{5} 위반: $no');
        expect(no[0], 'P');
      }
    });

    test('대문자만 사용(소문자 없음)', () {
      final gen = PassportNumberGenerator(random: Random(7));
      for (var i = 0; i < 200; i++) {
        final no = gen.generate();
        expect(no, no.toUpperCase());
      }
    });

    test('isValid: 올바른 형식만 통과', () {
      expect(PassportNumberGenerator.isValid('PAB12345'), isTrue);
      expect(PassportNumberGenerator.isValid('PZZ00000'), isTrue);
      // 실패 케이스
      expect(PassportNumberGenerator.isValid(null), isFalse);
      expect(PassportNumberGenerator.isValid(''), isFalse);
      expect(PassportNumberGenerator.isValid('AB12345'), isFalse); // P 없음
      expect(PassportNumberGenerator.isValid('PA12345'), isFalse); // 영문 1개
      expect(PassportNumberGenerator.isValid('PABC1234'), isFalse); // 영문 3개
      expect(PassportNumberGenerator.isValid('PAB1234'), isFalse); // 숫자 4개
      expect(PassportNumberGenerator.isValid('PAB123456'), isFalse); // 숫자 6개
      expect(PassportNumberGenerator.isValid('Pab12345'), isFalse); // 소문자
      expect(PassportNumberGenerator.isValid(' PAB12345'), isFalse); // 공백
    });

    test('같은 시드 → 같은 시퀀스(결정성, 테스트 안정성)', () {
      final a = PassportNumberGenerator(random: Random(123));
      final b = PassportNumberGenerator(random: Random(123));
      for (var i = 0; i < 10; i++) {
        expect(a.generate(), b.generate());
      }
    });
  });
}
