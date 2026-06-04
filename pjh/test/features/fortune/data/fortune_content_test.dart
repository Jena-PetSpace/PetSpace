import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_content_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/domain/entities/fortune_content.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';

const _species = [MbtiSpecies.dog, MbtiSpecies.cat, MbtiSpecies.etc];
const _groups = ['default', '분석가', '외교관', '관리자', '탐험가'];

void main() {
  // rootBundle 에셋 로드를 위해 바인딩 초기화 필요.
  TestWidgetsFlutterBinding.ensureInitialized();

  final dataSource = FortuneContentDataSourceImpl();
  late FortuneContent content;

  setUpAll(() async {
    content = await dataSource.loadContent(version: 1);
  });

  group('번들 JSON 무결성 (작업 0 검증의 Dart 버전)', () {
    test('version=1, 면책 문구 존재', () {
      expect(content.version, 1);
      expect(content.disclaimer.trim(), isNotEmpty);
    });

    test('종합운 3종×5그룹 각 6개 = 90개', () {
      var total = 0;
      for (final s in _species) {
        for (final g in _groups) {
          final pool = content.overall[s]?[g];
          expect(pool, isNotNull, reason: '$s.$g 누락');
          expect(pool!.length, 6, reason: '$s.$g 개수');
          total += pool.length;
        }
      }
      expect(total, 90);
    });

    test('items 종별 3개, 사용 key 가 itemPhrases 1~5 각 3개 보유 = 120개', () {
      final usedKeys = <String>{};
      for (final s in _species) {
        final items = content.itemsFor(s);
        expect(items.length, 3, reason: '$s items 개수');
        for (final it in items) {
          expect(it.key.trim(), isNotEmpty);
          expect(it.label.trim(), isNotEmpty);
          usedKeys.add(it.key);
        }
      }
      expect(usedKeys.length, 8); // insider,trouble,treat,chosen,rascal,spot,charm,sleep

      var total = 0;
      for (final k in usedKeys) {
        for (var star = 1; star <= 5; star++) {
          final pool = content.itemPhrasePool(k, star);
          expect(pool.length, 3, reason: '$k.$star 개수');
          total += pool.length;
        }
      }
      expect(total, 120);
    });

    test('lucky.treat/place 종별 풀 존재', () {
      for (final s in _species) {
        expect(content.luckyTreatPool(s), isNotEmpty, reason: '$s treat');
        expect(content.luckyPlacePool(s), isNotEmpty, reason: '$s place');
      }
    });

    test('{petName} 토큰이 default 종합운에 존재(치환 대상)', () {
      final hasToken = _species.any(
          (s) => content.overallPool(s, null).any((p) => p.contains('{petName}')));
      expect(hasToken, isTrue);
    });
  });

  group('overallPool 그룹 폴백', () {
    test('group=null → default 풀', () {
      final byDefault = content.overallPool(MbtiSpecies.dog, 'default');
      expect(content.overallPool(MbtiSpecies.dog, null), byDefault);
    });

    test('알 수 없는 group → default 풀', () {
      final byDefault = content.overallPool(MbtiSpecies.dog, 'default');
      expect(content.overallPool(MbtiSpecies.dog, '없는그룹'), byDefault);
    });

    test('유효 group → 해당 그룹 풀(default 와 다름)', () {
      final analyst = content.overallPool(MbtiSpecies.dog, '분석가');
      expect(analyst, isNotEmpty);
      expect(analyst, isNot(content.overallPool(MbtiSpecies.dog, 'default')));
    });
  });

  group('로더 동작', () {
    test('2회 로드 시 동일 인스턴스 캐시 반환', () async {
      final a = await dataSource.loadContent(version: 1);
      final b = await dataSource.loadContent(version: 1);
      expect(identical(a, b), isTrue);
    });
  });
}
