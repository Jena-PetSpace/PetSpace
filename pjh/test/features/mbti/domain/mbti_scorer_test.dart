import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/mbti/domain/entities/mbti_content.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';
import 'package:meong_nyang_diary/features/mbti/domain/services/mbti_scorer.dart';

/// 채점기 테스트용 합성 콘텐츠.
///
/// 축당 5문항, 각 문항 A=양극 / B=음극으로 단순화해 응답 패턴을 직접 제어한다.
/// (실제 JSON 의 문항 텍스트/극 배치와 무관하게 채점 로직만 검증)
MbtiContent _buildContent({int version = 1, String prefix = 'dog'}) {
  const axisDefs = {
    'EI': ['E', 'I'],
    'SN': ['S', 'N'],
    'TF': ['T', 'F'],
    'JP': ['J', 'P'],
  };

  final axes = <String, MbtiAxis>{};
  final questions = <MbtiQuestion>[];
  int n = 1;

  axisDefs.forEach((axisKey, poles) {
    axes[axisKey] = MbtiAxis(
      key: axisKey,
      name: axisKey,
      posCode: poles[0],
      posLabel: poles[0],
      negCode: poles[1],
      negLabel: poles[1],
    );
    for (int i = 0; i < 5; i++) {
      final id = '${prefix}_${n.toString().padLeft(2, '0')}';
      questions.add(MbtiQuestion(
        id: id,
        axis: axisKey,
        text: 'q$id',
        optionA: MbtiOption(label: 'A', pole: poles[0]), // A → 양극
        optionB: MbtiOption(label: 'B', pole: poles[1]), // B → 음극
      ));
      n++;
    }
  });

  return MbtiContent(
    version: version,
    disclaimer: 'test',
    questionsPerAxis: 5,
    axes: axes,
    groups: const {},
    questions: {MbtiSpecies.dog: questions},
    types: const {},
    compatibility: const {},
  );
}

/// 각 축에 (A 선택 개수)를 주면 그 패턴의 응답 리스트를 생성.
/// 예: aCounts = {'EI':5,'SN':4,'TF':3,'JP':0}
List<MbtiAnswer> _answers(MbtiContent content, Map<String, int> aCounts) {
  final out = <MbtiAnswer>[];
  final qs = content.questionsFor(MbtiSpecies.dog);
  for (final axisKey in kMbtiAxisOrder) {
    final axisQs = qs.where((q) => q.axis == axisKey).toList();
    final aCount = aCounts[axisKey] ?? 0;
    for (int i = 0; i < axisQs.length; i++) {
      out.add(MbtiAnswer(
        questionId: axisQs[i].id,
        choice: i < aCount ? 'A' : 'B',
      ));
    }
  }
  return out;
}

void main() {
  const scorer = MbtiScorer();
  final content = _buildContent();

  group('type_code 생성 (단순 다수결)', () {
    test('모든 A 선택 → ESTJ (각 축 양극)', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {'EI': 5, 'SN': 5, 'TF': 5, 'JP': 5}),
      );
      expect(outcome.isSuccess, isTrue);
      expect(outcome.scored!.typeCode, 'ESTJ');
    });

    test('모든 B 선택 → INFP (각 축 음극)', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {'EI': 0, 'SN': 0, 'TF': 0, 'JP': 0}),
      );
      expect(outcome.scored!.typeCode, 'INFP');
    });

    test('16유형이 모두 정상 생성된다 (가능한 우세 조합 전수)', () {
      // 각 축을 우세 양극(5)/우세 음극(0)으로 조합 → 2^4 = 16 유형.
      final generated = <String>{};
      for (final ei in [5, 0]) {
        for (final sn in [5, 0]) {
          for (final tf in [5, 0]) {
            for (final jp in [5, 0]) {
              final outcome = scorer.score(
                content: content,
                species: MbtiSpecies.dog,
                answers: _answers(
                    content, {'EI': ei, 'SN': sn, 'TF': tf, 'JP': jp}),
              );
              expect(outcome.isSuccess, isTrue);
              generated.add(outcome.scored!.typeCode);
            }
          }
        }
      }
      expect(generated.length, 16);
      // 4글자 코드, 각 자리 유효 극 확인
      const expected = {
        'ESTJ', 'ESTP', 'ESFJ', 'ESFP', 'ENTJ', 'ENTP', 'ENFJ', 'ENFP',
        'ISTJ', 'ISTP', 'ISFJ', 'ISFP', 'INTJ', 'INTP', 'INFJ', 'INFP',
      };
      expect(generated, expected);
    });
  });

  group('우세 극 · 퍼센트 (5:0 / 4:1 / 3:2)', () {
    test('5:0 → 우세 극, 퍼센트 100', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {'EI': 5, 'SN': 5, 'TF': 5, 'JP': 5}),
      );
      final s = outcome.scored!;
      expect(s.axisScores['EI']!.dominantPole, 'E');
      expect(s.axisScores['EI']!.positiveCount, 5);
      expect(s.axisScores['EI']!.negativeCount, 0);
      expect(s.axisPercents['EI'], 100);
    });

    test('4:1 → 우세 극, 퍼센트 80', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {'EI': 4, 'SN': 1, 'TF': 4, 'JP': 1}),
      );
      final s = outcome.scored!;
      // EI: A 4개 → E 우세 80%
      expect(s.axisScores['EI']!.dominantPole, 'E');
      expect(s.axisPercents['EI'], 80);
      // SN: A 1개 → S 1 / N 4 → N 우세 80%
      expect(s.axisScores['SN']!.dominantPole, 'N');
      expect(s.axisScores['SN']!.positiveCount, 1);
      expect(s.axisScores['SN']!.negativeCount, 4);
      expect(s.axisPercents['SN'], 80);
      expect(s.typeCode, 'ENTP'); // E, N, (TF A4→T), (JP A1→P)
    });

    test('3:2 → 우세 극, 퍼센트 60 (동점 아님)', () {
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {'EI': 3, 'SN': 2, 'TF': 3, 'JP': 2}),
      );
      final s = outcome.scored!;
      // EI: A 3 → E 3 / I 2 → E 우세 60%
      expect(s.axisScores['EI']!.dominantPole, 'E');
      expect(s.axisPercents['EI'], 60);
      // SN: A 2 → S 2 / N 3 → N 우세 60%
      expect(s.axisScores['SN']!.dominantPole, 'N');
      expect(s.axisPercents['SN'], 60);
    });

    test('열세 극 퍼센트 단계 (40/20/0) — dominantPercent 는 항상 우세 기준', () {
      // 우세가 60이면 열세는 40. 퍼센트 필드는 우세 극 기준만 노출.
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: _answers(content, {'EI': 3, 'SN': 4, 'TF': 5, 'JP': 3}),
      );
      final s = outcome.scored!;
      expect(s.axisPercents['EI'], 60); // 3:2
      expect(s.axisPercents['SN'], 80); // 4:1
      expect(s.axisPercents['TF'], 100); // 5:0
      expect(s.axisPercents['JP'], 60); // 3:2
    });
  });

  group('채점 가드 (입력 무결성)', () {
    test('응답 누락(축당 5개 미만) → incompleteAnswers, 채점 안 됨', () {
      final full = _answers(content, {'EI': 5, 'SN': 5, 'TF': 5, 'JP': 5});
      final partial = full.take(19).toList(); // 1개 누락
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: partial,
      );
      expect(outcome.isSuccess, isFalse);
      expect(outcome.error, MbtiScoringError.incompleteAnswers);
      expect(outcome.scored, isNull);
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
      final full = _answers(content, {'EI': 5, 'SN': 5, 'TF': 5, 'JP': 5});
      final bad = [
        ...full.take(19),
        const MbtiAnswer(questionId: 'nonexistent_99', choice: 'A'),
      ];
      final outcome = scorer.score(
        content: content,
        species: MbtiSpecies.dog,
        answers: bad,
      );
      expect(outcome.error, MbtiScoringError.invalidAnswer);
    });

    test('잘못된 choice → invalidAnswer', () {
      final full = _answers(content, {'EI': 5, 'SN': 5, 'TF': 5, 'JP': 5});
      final bad = [
        ...full.take(19),
        MbtiAnswer(questionId: full.last.questionId, choice: 'X'),
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
    test('채점 결과는 전달된 content 의 version 을 그대로 보존한다', () {
      final v2content = _buildContent(version: 2);
      final outcome = scorer.score(
        content: v2content,
        species: MbtiSpecies.dog,
        answers: _answers(v2content, {'EI': 5, 'SN': 5, 'TF': 5, 'JP': 5}),
      );
      expect(outcome.scored!.contentVersion, 2);
    });
  });
}
