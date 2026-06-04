import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/mbti/data/datasources/mbti_content_data_source.dart';
import 'package:meong_nyang_diary/features/mbti/data/models/pet_mbti_result_model.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/mbti_content.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';

const _axisOrder = ['EI', 'SN', 'TF', 'JP'];
const _axisPoles = {
  'EI': ['E', 'I'],
  'SN': ['S', 'N'],
  'TF': ['T', 'F'],
  'JP': ['J', 'P'],
};
const _all16 = [
  'ESTJ', 'ESTP', 'ESFJ', 'ESFP', 'ENTJ', 'ENTP', 'ENFJ', 'ENFP',
  'ISTJ', 'ISTP', 'ISFJ', 'ISFP', 'INTJ', 'INTP', 'INFJ', 'INFP',
];

void main() {
  // rootBundle 에셋 로드를 위해 바인딩 초기화 필요.
  TestWidgetsFlutterBinding.ensureInitialized();

  final dataSource = MbtiContentDataSourceImpl();
  late MbtiContent content;

  setUpAll(() async {
    content = await dataSource.loadContent(version: 1);
  });

  group('번들 JSON 무결성 (작업 0 검증의 Dart 버전)', () {
    test('version=1, 면책 문구 존재', () {
      expect(content.version, 1);
      expect(content.disclaimer.trim(), isNotEmpty);
      expect(content.questionsPerAxis, 5);
    });

    test('종별 문항 20개, 축당 5개, 4옵션, pole/weight 규칙', () {
      for (final species in MbtiSpecies.values) {
        final qs = content.questionsFor(species);
        expect(qs.length, 20, reason: '$species 문항 수');

        final perAxis = {for (final a in _axisOrder) a: 0};
        final ids = <String>{};
        for (final q in qs) {
          expect(ids.add(q.id), isTrue, reason: '중복 id ${q.id}');
          expect(_axisOrder.contains(q.axis), isTrue,
              reason: '${q.id} axis ${q.axis}');
          perAxis[q.axis] = perAxis[q.axis]! + 1;

          // 4옵션, weight [2,1,1,2], 극이 axis 두 극과 일치
          expect(q.options.length, 4, reason: '${q.id} 옵션 4개');
          final weights = q.options.map((o) => o.weight).toList();
          expect(weights, [2, 1, 1, 2], reason: '${q.id} weights');
          final poles = q.options.map((o) => o.pole).toList();
          final axisPoles = _axisPoles[q.axis]!;
          // A,B 같은 극 / C,D 같은 극, 두 극이 axis 와 일치
          expect(poles[0] == poles[1], isTrue, reason: '${q.id} A/B 극 동일');
          expect(poles[2] == poles[3], isTrue, reason: '${q.id} C/D 극 동일');
          expect({poles[0], poles[2]}, axisPoles.toSet(),
              reason: '${q.id} 옵션 극이 axis ${q.axis} 와 불일치');
        }
        for (final a in _axisOrder) {
          expect(perAxis[a], 5, reason: '$species $a 문항 수');
        }
      }
    });

    test('answerIntensities 메타 제거됨 (옵션 weight 직접 사용)', () {
      // 강도 꼬리표 방식 제거 — 옵션이 weight 를 직접 가짐
      final firstOpt = content.questionsFor(MbtiSpecies.dog).first.options.first;
      expect(firstOpt.weight, anyOf(1, 2));
    });

    test('16유형 × 3종, 6필드 전부 보유 + group 존재', () {
      expect(content.types.length, 16);
      for (final code in _all16) {
        final info = content.typeInfo(code);
        expect(info, isNotNull, reason: '유형 $code 누락');
        expect(info!.group.trim(), isNotEmpty, reason: '$code group');
        for (final species in MbtiSpecies.values) {
          final d = info.details[species];
          expect(d, isNotNull, reason: '$code.$species 상세 누락');
          expect(d!.nickname.trim(), isNotEmpty, reason: '$code.$species nickname');
          expect(d.summary.trim(), isNotEmpty, reason: '$code.$species summary');
          expect(d.desc.trim(), isNotEmpty, reason: '$code.$species desc');
          expect(d.strength.trim(), isNotEmpty, reason: '$code.$species strength');
          expect(d.caution.trim(), isNotEmpty, reason: '$code.$species caution');
          expect(d.activity.trim(), isNotEmpty, reason: '$code.$species activity');
        }
      }
    });

    test('궁합 16행, dog+cat 각 type+reason, 참조 type 유효', () {
      expect(content.compatibility.length, 16);
      for (final code in _all16) {
        final c = content.compatibilityFor(code);
        expect(c, isNotNull, reason: '궁합 $code 누락');
        expect(_all16.contains(c!.dog.type), isTrue,
            reason: '$code.dog type ${c.dog.type} 무효');
        expect(c.dog.reason.trim(), isNotEmpty);
        expect(_all16.contains(c.cat.type), isTrue,
            reason: '$code.cat type ${c.cat.type} 무효');
        expect(c.cat.reason.trim(), isNotEmpty);
      }
    });

    test('그룹 색상 매핑 (분석가/외교관/관리자/탐험가)', () {
      expect(content.colorForGroup('분석가'), 'purple');
      expect(content.colorForGroup('외교관'), 'coral');
      expect(content.colorForGroup('관리자'), 'navy');
      expect(content.colorForGroup('탐험가'), 'teal');
    });
  });

  group('로더 동작', () {
    test('2회 로드 시 동일 인스턴스 캐시 반환', () async {
      final a = await dataSource.loadContent(version: 1);
      final b = await dataSource.loadContent(version: 1);
      expect(identical(a, b), isTrue);
    });
  });

  group('모델 왕복 (fromJson ↔ toInsertJson)', () {
    test('axis_scores / answers 왕복 보존', () {
      final original = PetMbtiResultModel(
        id: 'r1',
        petId: 'pet-1',
        species: MbtiSpecies.dog,
        typeCode: 'ENFP',
        axisScores: const {
          'EI': AxisScore(
              positivePole: 'E',
              negativePole: 'I',
              positiveCount: 4,
              negativeCount: 1),
          'SN': AxisScore(
              positivePole: 'S',
              negativePole: 'N',
              positiveCount: 2,
              negativeCount: 3),
          'TF': AxisScore(
              positivePole: 'T',
              negativePole: 'F',
              positiveCount: 1,
              negativeCount: 4),
          'JP': AxisScore(
              positivePole: 'J',
              negativePole: 'P',
              positiveCount: 2,
              negativeCount: 3),
        },
        answers: const [
          MbtiAnswer(questionId: 'dog_01', optionIndex: 0),
          MbtiAnswer(questionId: 'dog_02', optionIndex: 3),
        ],
        contentVersion: 1,
        createdAt: _fixedDate,
      );

      // toInsertJson 은 DB INSERT 형태 — id/created_at 제외. 서버가 채운다고
      // 가정하고 fromJson 으로 복원하기 위해 보강.
      final insertJson = original.toInsertJson();
      final roundTripSource = {
        ...insertJson,
        'id': original.id,
        'created_at': original.createdAt.toIso8601String(),
      };
      final restored = PetMbtiResultModel.fromJson(roundTripSource);

      expect(restored.typeCode, 'ENFP');
      expect(restored.species, MbtiSpecies.dog);
      expect(restored.contentVersion, 1);
      // axis 원점수 보존
      expect(restored.axisScores['EI']!.positiveCount, 4);
      expect(restored.axisScores['EI']!.negativeCount, 1);
      expect(restored.axisScores['SN']!.negativeCount, 3);
      expect(restored.axisScores['TF']!.negativeCount, 4);
      // answers 보존 (optionIndex)
      expect(restored.answers.length, 2);
      expect(restored.answers.first.questionId, 'dog_01');
      expect(restored.answers.first.optionIndex, 0);
      expect(restored.answers[1].optionIndex, 3);
    });

    test('axisScoresToJson 형태 = {"EI":{"E":4,"I":1}}', () {
      final model = PetMbtiResultModel(
        id: 'r',
        petId: 'p',
        species: MbtiSpecies.cat,
        typeCode: 'INTJ',
        axisScores: const {
          'EI': AxisScore(
              positivePole: 'E',
              negativePole: 'I',
              positiveCount: 1,
              negativeCount: 4),
        },
        answers: const [],
        contentVersion: 1,
        createdAt: _fixedDate,
      );
      final json = model.axisScoresToJson();
      expect(json['EI'], {'E': 1, 'I': 4});
    });
  });
}

final _fixedDate = DateTime(2026, 6, 3);
