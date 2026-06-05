import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/fortune/domain/services/fortune_group.dart';

const _all16 = [
  'ESTJ', 'ESTP', 'ESFJ', 'ESFP', 'ENTJ', 'ENTP', 'ENFJ', 'ENFP',
  'ISTJ', 'ISTP', 'ISFJ', 'ISFP', 'INTJ', 'INTP', 'INFJ', 'INFP',
];

void main() {
  group('mbtiGroupOf — 코드 4글자 순수 계산', () {
    test('16유형 전수 매핑 (NT=분석가, NF=외교관, SJ=관리자, SP=탐험가)', () {
      final expected = <String, String>{};
      for (final c in _all16) {
        final n = c[1], t = c[2], j = c[3];
        if (n == 'N' && t == 'T') {
          expected[c] = '분석가';
        } else if (n == 'N' && t == 'F') {
          expected[c] = '외교관';
        } else if (n == 'S' && j == 'J') {
          expected[c] = '관리자';
        } else {
          expected[c] = '탐험가'; // S*P
        }
      }
      for (final c in _all16) {
        expect(mbtiGroupOf(c), expected[c], reason: c);
      }
      // 그룹별 4개씩 균등 분포 확인
      final counts = <String, int>{};
      for (final c in _all16) {
        counts[mbtiGroupOf(c)!] = (counts[mbtiGroupOf(c)!] ?? 0) + 1;
      }
      expect(counts, {'분석가': 4, '외교관': 4, '관리자': 4, '탐험가': 4});
    });

    test('소문자도 정규화', () {
      expect(mbtiGroupOf('enfp'), '외교관');
      expect(mbtiGroupOf('  IntJ '), '분석가');
    });

    test('null/빈값/형식불일치 → null (default 폴백 유도)', () {
      expect(mbtiGroupOf(null), isNull);
      expect(mbtiGroupOf(''), isNull);
      expect(mbtiGroupOf('ENF'), isNull); // 3글자
      expect(mbtiGroupOf('ENFPX'), isNull); // 5글자
    });
  });
}
