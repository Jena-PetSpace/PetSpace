import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/mbti/domain/entities/mbti_content.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';
import 'package:meong_nyang_diary/features/mbti/domain/services/mbti_scorer.dart';

/// 채점기 테스트용 합성 콘텐츠.
///
/// 축당 [questionsPerAxis]문항, 각 문항 4옵션(원고 규칙):
///   index 0 = pos·weight2 / 1 = pos·weight1 / 2 = neg·weight1 / 3 = neg·weight2
MbtiContent _buildContent({int version = 1, int questionsPerAxis = 5}) {
  const axisDefs = {
    'EI': ['E', 'I'],
    'SN': ['S', 'N'],
    'TF': ['T', 'F'],
    'JP': ['J', 'P'],
  };

  final axes = <String, MbtiAxis>{};
  final questions = <MbtiQuestion>[];
  final counters = <String, int>{};

  axisDefs.forEach((axisKey, poles) {
    axes[axisKey] = MbtiAxis(
      key: axisKey,
      name: axisKey,
      posCode: poles[0],
      posLabel: poles[0],
      negCode: poles[1],
      negLabel: poles[1],
    );
    for (int i = 0; i < questionsPerAxis; i++) {
      counters[axisKey] = (counters[axisKey] ?? 0) + 1;
      questions.add(MbtiQuestion(
        id: '${axisKey}_${counters[axisKey]}',
        axis: axisKey,
        text: 'q',
        options: [
          MbtiOption(label: '${poles[0]} strong', pole: poles[0], weight: 2),
          MbtiOption(label: '${poles[0]} mild', pole: poles[0], weight: 1),
          MbtiOption(label: '${poles[1]} mild', pole: poles[1], weight: 1),
          MbtiOption(label: '${poles[1]} strong', pole: poles[1], weight: 2),
        ],
      ));
    }
  });

  return MbtiContent(
    version: version,
    disclaimer: 'test',
    questionsPerAxis: questionsPerAxis,
    axes: axes,
    groups: const {},
    questions: {MbtiSpecies.dog: questions},
    types: const {},
    compatibility: const {},
  );
}

/// 옵션 인덱스 상수
const int kPosStrong = 0; // pos ·2
const int kPosMild = 1; // pos ·1
const int kNegMild = 2; // neg ·1
const int kNegStrong = 3; // neg ·2

/// 각 축에 [축키 -> 옵션인덱스 5개] 패턴을 주면 응답 리스트 생성.
List<MbtiAnswer> _answers(MbtiContent content, Map<String, List<int>> pattern) {
  final out = <MbtiAnswer>[];
  final qs = content.questionsFor(MbtiSpecies.dog);
  for (final axisKey in kMbtiAxisOrder) {
    final axisQs = qs.where((q) => q.axis == axisKey).toList();
    final idxs = pattern[axisKey] ?? List.filled(axisQs.length, kNegStrong);
    for (int i = 0; i < axisQs.length; i++) {
      out.add(MbtiAnswer(
        questionId: axisQs[i].id,
        optionIndex: i < idxs.length ? idxs[i] : kNegStrong,
      ));
    }
  }
  return out;
}

/// 한 축 5문항 모두 같은 옵션 인덱스로 채우는 헬퍼.
List<int> _all(int idx) => List.filled(5, idx);

void main() {
  const scorer = MbtiScorer();
  final content = _buildContent();

  group('type_code 생성 (가중 다수결)', () {
    test('모든 pos·strong → ESTJ', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {
          'EI': _all(kPosStrong),
          'SN': _all(kPosStrong),
          'TF': _all(kPosStrong),
          'JP': _all(kPosStrong),
        }),
      );
      expect(outcome.isSuccess, isTrue);
      expect(outcome.scored!.typeCode, 'ESTJ');
      // 5문항 × pos·2 = 10점
      expect(outcome.scored!.axisScores['EI']!.positiveCount, 10);
      expect(outcome.scored!.axisScores['EI']!.negativeCount, 0);
      expect(outcome.scored!.axisPercents['EI'], 100);
    });

    test('모든 neg·strong → INFP', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {
          'EI': _all(kNegStrong),
          'SN': _all(kNegStrong),
          'TF': _all(kNegStrong),
          'JP': _all(kNegStrong),
        }),
      );
      expect(outcome.scored!.typeCode, 'INFP');
    });

    test('16유형 전수 생성 (pos·strong / neg·strong 조합)', () {
      final generated = <String>{};
      for (final ei in [kPosStrong, kNegStrong]) {
        for (final sn in [kPosStrong, kNegStrong]) {
          for (final tf in [kPosStrong, kNegStrong]) {
            for (final jp in [kPosStrong, kNegStrong]) {
              final o = scorer.score(
                content: content,
                species: MbtiSpecies.dog,
                answers: _answers(content, {
                  'EI': _all(ei),
                  'SN': _all(sn),
                  'TF': _all(tf),
                  'JP': _all(jp),
                }),
              );
              generated.add(o.scored!.typeCode);
            }
          }
        }
      }
      expect(generated.length, 16);
      const expected = {
        'ESTJ', 'ESTP', 'ESFJ', 'ESFP', 'ENTJ', 'ENTP', 'ENFJ', 'ENFP',
        'ISTJ', 'ISTP', 'ISFJ', 'ISFP', 'INTJ', 'INTP', 'INFJ', 'INFP',
      };
      expect(generated, expected);
    });
  });

  group('가중 점수 · 퍼센트', () {
    test('pos·strong3 + pos·mild1 + neg·mild1 → E7 I1, 88%', () {
      // E = 3*2 + 1*1 = 7, I = 1*1 = 1 → 7/8 = 88%
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {
          'EI': [kPosStrong, kPosStrong, kPosStrong, kPosMild, kNegMild],
          'SN': _all(kPosStrong),
          'TF': _all(kPosStrong),
          'JP': _all(kPosStrong),
        }),
      );
      final s = outcome.scored!;
      expect(s.axisScores['EI']!.positiveCount, 7);
      expect(s.axisScores['EI']!.negativeCount, 1);
      expect(s.axisPercents['EI'], 88);
      expect(s.axisScores['EI']!.dominantPole, 'E');
    });

    test('pos·strong3 + neg·strong2 → E6 I4, 60%', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {
          'EI': [kPosStrong, kPosStrong, kPosStrong, kNegStrong, kNegStrong],
          'SN': _all(kPosStrong),
          'TF': _all(kPosStrong),
          'JP': _all(kPosStrong),
        }),
      );
      final s = outcome.scored!;
      expect(s.axisScores['EI']!.positiveCount, 6);
      expect(s.axisScores['EI']!.negativeCount, 4);
      expect(s.axisPercents['EI'], 60);
    });

    test('축당 한 극 최대 10점 (mild5 → 5점)', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {
          'EI': _all(kPosMild), // pos ·1 ×5 = 5
          'SN': _all(kPosStrong),
          'TF': _all(kPosStrong),
          'JP': _all(kPosStrong),
        }),
      );
      expect(outcome.scored!.axisScores['EI']!.positiveCount, 5);
      expect(outcome.scored!.axisScores['EI']!.negativeCount, 0);
      expect(outcome.scored!.axisPercents['EI'], 100);
    });
  });

  group('채점 가드 (입력 무결성)', () {
    test('응답 누락(20문항 미만) → incompleteAnswers', () {
      final full = _answers(content, {
        'EI': _all(kPosStrong),
        'SN': _all(kPosStrong),
        'TF': _all(kPosStrong),
        'JP': _all(kPosStrong),
      });
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: full.take(19).toList(),
      );
      expect(outcome.isSuccess, isFalse);
      expect(outcome.error, MbtiScoringError.incompleteAnswers);
    });

    test('빈 응답 → incompleteAnswers', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: const [],
      );
      expect(outcome.error, MbtiScoringError.incompleteAnswers);
    });

    test('알 수 없는 q_id → invalidAnswer', () {
      final full = _answers(content, {
        'EI': _all(kPosStrong),
        'SN': _all(kPosStrong),
        'TF': _all(kPosStrong),
        'JP': _all(kPosStrong),
      });
      final bad = [
        ...full.take(19),
        const MbtiAnswer(questionId: 'nope_99', optionIndex: 0),
      ];
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: bad,
      );
      expect(outcome.error, MbtiScoringError.invalidAnswer);
    });

    test('범위 밖 옵션 인덱스 → invalidAnswer', () {
      final full = _answers(content, {
        'EI': _all(kPosStrong),
        'SN': _all(kPosStrong),
        'TF': _all(kPosStrong),
        'JP': _all(kPosStrong),
      });
      final bad = [
        MbtiAnswer(questionId: full.first.questionId, optionIndex: 9),
        ...full.skip(1),
      ];
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: bad,
      );
      expect(outcome.error, MbtiScoringError.invalidAnswer);
    });
  });

  group('content_version 처리', () {
    test('결과는 전달된 content 의 version 을 그대로 보존', () {
      final v2 = _buildContent(version: 2);
      final outcome = scorer.score(
        content: v2,
        species: MbtiSpecies.dog,
        answers: _answers(v2, {
          'EI': _all(kPosStrong),
          'SN': _all(kPosStrong),
          'TF': _all(kPosStrong),
          'JP': _all(kPosStrong),
        }),
      );
      expect(outcome.scored!.contentVersion, 2);
    });
  });

  group('동점 폴백', () {
    // 4문항 축으로 가중·문항 완전 동점 구성 (EI만 4문항, 나머지 1문항).
    MbtiContent fourAxis(int eiQ) {
      const defs = {
        'EI': ['E', 'I'],
        'SN': ['S', 'N'],
        'TF': ['T', 'F'],
        'JP': ['J', 'P'],
      };
      final axes = <String, MbtiAxis>{};
      final qs = <MbtiQuestion>[];
      defs.forEach((k, p) {
        axes[k] = MbtiAxis(
            key: k,
            name: k,
            posCode: p[0],
            posLabel: p[0],
            negCode: p[1],
            negLabel: p[1]);
        final count = k == 'EI' ? eiQ : 1;
        for (int i = 0; i < count; i++) {
          qs.add(MbtiQuestion(
            id: '${k}_$i',
            axis: k,
            text: 'q',
            options: [
              MbtiOption(label: 'a', pole: p[0], weight: 2),
              MbtiOption(label: 'b', pole: p[0], weight: 1),
              MbtiOption(label: 'c', pole: p[1], weight: 1),
              MbtiOption(label: 'd', pole: p[1], weight: 2),
            ],
          ));
        }
      });
      return MbtiContent(
        version: 1,
        disclaimer: '',
        questionsPerAxis: 5,
        axes: axes,
        groups: const {},
        questions: {MbtiSpecies.dog: qs},
        types: const {},
        compatibility: const {},
      );
    }

    List<MbtiAnswer> others() => const [
          MbtiAnswer(questionId: 'SN_0', optionIndex: 0),
          MbtiAnswer(questionId: 'TF_0', optionIndex: 0),
          MbtiAnswer(questionId: 'JP_0', optionIndex: 0),
        ];

    test('가중·문항 모두 동점(EI 4문항) → 기본극 I', () {
      final c = fourAxis(4);
      // pos: strong1(2)+mild1(1)=3 votes2 / neg: strong1(2)+mild1(1)=3 votes2 → 동점
      final answers = [
        const MbtiAnswer(questionId: 'EI_0', optionIndex: kPosStrong),
        const MbtiAnswer(questionId: 'EI_1', optionIndex: kPosMild),
        const MbtiAnswer(questionId: 'EI_2', optionIndex: kNegStrong),
        const MbtiAnswer(questionId: 'EI_3', optionIndex: kNegMild),
        ...others(),
      ];
      final o = scorer.score(
          content: c, species: MbtiSpecies.dog, answers: answers);
      expect(o.isSuccess, isTrue);
      expect(o.scored!.typeCode[0], 'I');
    });

    test('가중 동점 + 문항 다수결 (EI 3문항, A votes 우세 → E)', () {
      final c = fourAxis(3);
      // pos: mild1(1)+mild1(1)=2 votes2 / neg: strong1(2)=2 votes1 → 가중동점 → 문항다수결 E
      final answers = [
        const MbtiAnswer(questionId: 'EI_0', optionIndex: kPosMild),
        const MbtiAnswer(questionId: 'EI_1', optionIndex: kPosMild),
        const MbtiAnswer(questionId: 'EI_2', optionIndex: kNegStrong),
        ...others(),
      ];
      final o = scorer.score(
          content: c, species: MbtiSpecies.dog, answers: answers);
      expect(o.scored!.typeCode[0], 'E');
    });
  });
}
