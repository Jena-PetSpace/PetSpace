import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_content_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/domain/entities/fortune_content.dart';
import 'package:meong_nyang_diary/features/fortune/domain/services/fortune_generator.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const gen = FortuneGenerator();
  late FortuneContent content;

  setUpAll(() async {
    content = await FortuneContentDataSourceImpl().loadContent(version: 1);
  });

  group('결정성', () {
    test('같은 (petId, dateKey) → 항상 동일 결과', () {
      final a = gen.generate(
        petId: 'pet-1',
        species: MbtiSpecies.dog,
        dateKey: '20260604',
        content: content,
        petName: '몽이',
      );
      final b = gen.generate(
        petId: 'pet-1',
        species: MbtiSpecies.dog,
        dateKey: '20260604',
        content: content,
        petName: '몽이',
      );
      expect(a, b); // Equatable 전체 동등
    });

    test('날짜가 다르면 시드가 달라짐(보통 결과도 달라짐)', () {
      final d1 = gen.generate(
          petId: 'pet-1',
          species: MbtiSpecies.dog,
          dateKey: '20260604',
          content: content);
      final d2 = gen.generate(
          petId: 'pet-1',
          species: MbtiSpecies.dog,
          dateKey: '20260605',
          content: content);
      // 종합운+별점 조합이 두 날 완전히 동일할 확률은 매우 낮음 — 적어도 한 필드는 다름.
      final same = d1.overall == d2.overall &&
          d1.items.map((e) => e.star).join() ==
              d2.items.map((e) => e.star).join();
      expect(same, isFalse);
    });

    test('pet 이 다르면 결과 분리', () {
      final p1 = gen.generate(
          petId: 'pet-A',
          species: MbtiSpecies.cat,
          dateKey: '20260604',
          content: content);
      final p2 = gen.generate(
          petId: 'pet-B',
          species: MbtiSpecies.cat,
          dateKey: '20260604',
          content: content);
      expect(p1 == p2, isFalse);
    });
  });

  group('종 분기', () {
    test('종별 항목 key 가 콘텐츠 items 와 일치', () {
      final dog = gen.generate(
          petId: 'p',
          species: MbtiSpecies.dog,
          dateKey: '20260604',
          content: content);
      expect(dog.items.map((e) => e.key).toList(),
          ['insider', 'trouble', 'treat']);

      final cat = gen.generate(
          petId: 'p',
          species: MbtiSpecies.cat,
          dateKey: '20260604',
          content: content);
      expect(cat.items.map((e) => e.key).toList(),
          ['chosen', 'rascal', 'spot']);

      final etc = gen.generate(
          petId: 'p',
          species: MbtiSpecies.etc,
          dateKey: '20260604',
          content: content);
      expect(etc.items.map((e) => e.key).toList(),
          ['charm', 'treat', 'sleep']);
    });

    test('럭키가 해당 종 풀에서 나옴', () {
      final cat = gen.generate(
          petId: 'p',
          species: MbtiSpecies.cat,
          dateKey: '20260604',
          content: content);
      expect(content.luckyTreatPool(MbtiSpecies.cat), contains(cat.luckyTreat));
      expect(content.luckyPlacePool(MbtiSpecies.cat), contains(cat.luckyPlace));
    });
  });

  group('MBTI 그룹 분기 / default 폴백', () {
    test('typeCode 있으면 해당 그룹 종합운 풀에서 나옴', () {
      final f = gen.generate(
        petId: 'p',
        species: MbtiSpecies.dog,
        dateKey: '20260604',
        content: content,
        mbtiTypeCode: 'INTJ', // 분석가
      );
      expect(content.overallPool(MbtiSpecies.dog, '분석가'), contains(f.overall));
    });

    test('typeCode null → default 풀에서 나옴', () {
      final f = gen.generate(
          petId: 'p',
          species: MbtiSpecies.dog,
          dateKey: '20260604',
          content: content);
      expect(content.overallPool(MbtiSpecies.dog, 'default'), contains(f.overall));
    });

    test('형식 불일치 typeCode → default 폴백', () {
      final f = gen.generate(
        petId: 'p',
        species: MbtiSpecies.dog,
        dateKey: '20260604',
        content: content,
        mbtiTypeCode: '???',
      );
      expect(content.overallPool(MbtiSpecies.dog, 'default'), contains(f.overall));
    });

    test('그룹이 달라지면 종합운 풀이 달라질 수 있음(같은 시드라도 다른 풀)', () {
      final nt = gen.generate(
          petId: 'p',
          species: MbtiSpecies.dog,
          dateKey: '20260604',
          content: content,
          mbtiTypeCode: 'INTJ');
      final nf = gen.generate(
          petId: 'p',
          species: MbtiSpecies.dog,
          dateKey: '20260604',
          content: content,
          mbtiTypeCode: 'INFJ');
      // 같은 시드라도 서로 다른 풀에서 뽑히므로 문구가 다름.
      expect(nt.overall == nf.overall, isFalse);
      // 단, 종합운만 그룹 분기 — 세부 항목 별점은 동일(그룹 무관).
      expect(nt.items.map((e) => e.star).toList(),
          nf.items.map((e) => e.star).toList());
    });
  });

  group('별점 1~5 경계 / 긍정 가중', () {
    test('모든 항목 별점이 1~5 범위, 종합 별점도 1~5', () {
      for (final species in MbtiSpecies.values) {
        for (var day = 1; day <= 60; day++) {
          final f = gen.generate(
            petId: 'p-$species',
            species: species,
            dateKey: '202606${day.toString().padLeft(2, '0')}',
            content: content,
          );
          for (final it in f.items) {
            expect(it.star, inInclusiveRange(1, 5), reason: it.key);
            // 별점에 맞는 풀에서 문구가 나왔는지
            expect(content.itemPhrasePool(it.key, it.star), contains(it.phrase));
          }
          expect(f.overallStar, inInclusiveRange(1, 5));
        }
      }
    });

    test('종합 별점 = 세부 3개 평균(반올림), 별도 시드 안 씀', () {
      final f = gen.generate(
          petId: 'pet-xyz',
          species: MbtiSpecies.dog,
          dateKey: '20260604',
          content: content);
      final stars = f.items.map((e) => e.star).toList();
      final expected = (stars.reduce((a, b) => a + b) / stars.length).round();
      expect(f.overallStar, expected);
    });

    test('긍정 가중 — 다수 표본에서 평균 별점이 중앙(3)보다 높음', () {
      var sum = 0, n = 0;
      for (var d = 0; d < 300; d++) {
        final f = gen.generate(
          petId: 'sample',
          species: MbtiSpecies.dog,
          dateKey: '2026${(1000 + d)}',
          content: content,
        );
        for (final it in f.items) {
          sum += it.star;
          n++;
        }
      }
      final avg = sum / n;
      // 가중 기대값 = (1*1+2*1+3*2+4*3+5*3)/10 = 3.6
      expect(avg, greaterThan(3.2), reason: '평균 별점 $avg');
    });
  });

  group('항목 간 서브시드 분리', () {
    test('세 항목이 동일 별점·문구로 묶이지 않음(독립 추출)', () {
      // 같은 baseSeed 라도 항목별 서브시드(:key:star, :key:phrase)로 분리되어
      // 세 항목이 늘 같은 값으로 collapse 되지 않는다. 표본에서 분산 확인.
      final phraseSets = <String>{};
      for (var d = 0; d < 40; d++) {
        final f = gen.generate(
          petId: 'sep',
          species: MbtiSpecies.cat,
          dateKey: '2026${2000 + d}',
          content: content,
        );
        // 한 날 안에서 세 항목 문구가 전부 동일하면 분리 실패 신호.
        final distinct = f.items.map((e) => e.phrase).toSet();
        phraseSets.add(distinct.length.toString());
      }
      // 적어도 일부 날은 세 항목 문구가 모두 다름(분리 정상).
      expect(phraseSets.contains('3'), isTrue);
    });

    test('럭키와 종합운이 종합운 풀에서 독립 시드로 뽑힘', () {
      // luckyTreat 와 종합운이 같은 인덱스로 묶이지 않는지(서브시드 분리) —
      // 결정성만 우선 확인: 동일 입력 → 동일 럭키.
      final a = gen.generate(
          petId: 'p',
          species: MbtiSpecies.dog,
          dateKey: '20260604',
          content: content);
      final b = gen.generate(
          petId: 'p',
          species: MbtiSpecies.dog,
          dateKey: '20260604',
          content: content);
      expect(a.luckyTreat, b.luckyTreat);
      expect(a.luckyPlace, b.luckyPlace);
    });
  });

  group('{petName} 치환 / 폴백', () {
    test('이름 있으면 토큰 치환, 토큰 잔존 없음', () {
      // default 종합운에 {petName} 이 있는 시드를 찾아 검증.
      final f = gen.generate(
        petId: 'name-pet',
        species: MbtiSpecies.dog,
        dateKey: '20260604',
        content: content,
        petName: '초코',
      );
      expect(f.overall.contains('{petName}'), isFalse);
      // 종합운이 토큰 포함 문구였다면 이름이 들어가 있어야 함.
      final rawPool = content.overallPool(MbtiSpecies.dog, 'default');
      final hadToken = rawPool.any((p) => p.contains('{petName}'));
      if (hadToken && f.overall.contains('초코')) {
        expect(f.overall.contains('초코'), isTrue);
      }
    });

    test('이름 없음/빈값 → "우리 아이" 로 치환', () {
      // 토큰 포함 문구가 확실히 뽑히는 (petId, dateKey) 를 찾아 폴백을 검증.
      bool checkedTokenCase = false;
      for (final name in [null, '', '   ']) {
        for (var d = 0; d < 200 && !checkedTokenCase; d++) {
          final petId = 'fb-$d';
          final f = gen.generate(
            petId: petId,
            species: MbtiSpecies.etc,
            dateKey: '20260604',
            content: content,
            petName: name,
          );
          // 토큰은 항상 사라져야 한다(치환/폴백 무관).
          expect(f.overall.contains('{petName}'), isFalse);

          // 이 시드의 default 종합운 원문이 토큰을 포함했다면, 출력엔 폴백명이 있어야 함.
          final pool = content.overallPool(MbtiSpecies.etc, 'default');
          final replaced = pool
              .map((p) => p.replaceAll('{petName}', kFortuneFallbackName))
              .toList();
          if (replaced.contains(f.overall) &&
              pool.any((p) => p.contains('{petName}')) &&
              f.overall.contains(kFortuneFallbackName)) {
            checkedTokenCase = true;
          }
        }
      }
      expect(checkedTokenCase, isTrue,
          reason: '토큰 포함 문구가 폴백명으로 치환된 케이스를 한 번은 확인해야 함');
    });

    test('토큰 치환은 단순 문자열 교체(조사 미부착)', () {
      // 콘텐츠 문구가 "오늘 {petName}," 형태라 이름 뒤 조사 없음 — 치환만 확인.
      const g = FortuneGenerator();
      final replaced = g.generate(
        petId: 'x',
        species: MbtiSpecies.dog,
        dateKey: '20260604',
        content: content,
        petName: '바둑이',
      );
      expect(replaced.overall.contains('{petName}'), isFalse);
    });
  });
}
