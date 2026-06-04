import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/mbti/domain/entities/mbti_content.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';
import 'package:meong_nyang_diary/features/mbti/domain/services/mbti_scorer.dart';

/// 채점기 테스트용 합성 콘텐츠.
///
/// 축당 5문항, 각 문항 A=양극 / B=음극으로 단순화해 응답 패턴을 직접 제어한다.
/// (실제 JSON 의 문항 텍스트/극 배치와 무관하게 채점 로직만 검증)
MbtiContent _buildContent({
  int version = 1,
  String prefix = 'dog',
  bool withIntensity = false,
}) {
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
    answerIntensities: withIntensity
        ? const [
            MbtiIntensity(id: 'strong', label: '확실히', weight: 2),
            MbtiIntensity(id: 'mild', label: '약간', weight: 1),
          ]
        : const [],
  );
}

/// 가중 응답 생성: 각 축에 (강한A, 약한A, 약한B, 강한B) 개수를 지정.
/// 합은 5(축당 문항 수)여야 한다.
List<MbtiAnswer> _weightedAnswers(
  MbtiContent content,
  Map<String, List<int>> pattern, // [strongA, mildA, mildB, strongB]
) {
  final out = <MbtiAnswer>[];
  final qs = content.questionsFor(MbtiSpecies.dog);
  for (final axisKey in kMbtiAxisOrder) {
    final axisQs = qs.where((q) => q.axis == axisKey).toList();
    final p = pattern[axisKey] ?? const [0, 0, 0, 5];
    final seq = <MbtiAnswer>[];
    void add(int count, String choice, String intensity) {
      for (int i = 0; i < count; i++) {
        seq.add(MbtiAnswer(
            questionId: '', choice: choice, intensity: intensity));
      }
    }

    add(p[0], 'A', 'strong');
    add(p[1], 'A', 'mild');
    add(p[2], 'B', 'mild');
    add(p[3], 'B', 'strong');
    for (int i = 0; i < axisQs.length && i < seq.length; i++) {
      out.add(MbtiAnswer(
        questionId: axisQs[i].id,
        choice: seq[i].choice,
        intensity: seq[i].intensity,
      ));
    }
  }
  return out;
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

  // ── 4지선다(강도 가중) 모드 ─────────────────────────────────
  group('가중 채점 (strong=2, mild=1)', () {
    final wc = _buildContent(withIntensity: true);

    test('strong A 5개 → E 10점, 퍼센트 100', () {
      final outcome = scorer.score(
        content: wc,
        species: MbtiSpecies.dog,
        answers: _weightedAnswers(wc, {
          'EI': [5, 0, 0, 0], // strongA×5 → E 10
          'SN': [5, 0, 0, 0],
          'TF': [5, 0, 0, 0],
          'JP': [5, 0, 0, 0],
        }),
      );
      final s = outcome.scored!;
      expect(s.axisScores['EI']!.positiveCount, 10); // E 가중합
      expect(s.axisScores['EI']!.negativeCount, 0);
      expect(s.axisPercents['EI'], 100);
      expect(s.typeCode, 'ESTJ');
    });

    test('강도 혼합 — E7 I1 → 88% (strongA3 + mildA1 + mildB1)', () {
      // strongA×3=6, mildA×1=1 → E 7 / mildB×1=1 → I 1. 문항 3+1+1=5 ✓
      final outcome = scorer.score(
        content: wc,
        species: MbtiSpecies.dog,
        answers: _weightedAnswers(wc, {
          'EI': [3, 1, 1, 0],
          'SN': [5, 0, 0, 0],
          'TF': [5, 0, 0, 0],
          'JP': [5, 0, 0, 0],
        }),
      );
      final s = outcome.scored!;
      expect(s.axisScores['EI']!.positiveCount, 7); // E = 3*2 + 1*1
      expect(s.axisScores['EI']!.negativeCount, 1); // I = 1*1
      expect(s.axisPercents['EI'], 88); // 7/8 = 87.5 → 88
      expect(s.axisScores['EI']!.dominantPole, 'E');
    });

    test('강도 혼합 — E6 I4 → 60% (strongA3 + strongB2)', () {
      // strongA×3=6 → E 6 / strongB×2=4 → I 4. 합 10, 60%.
      final outcome = scorer.score(
        content: wc,
        species: MbtiSpecies.dog,
        answers: _weightedAnswers(wc, {
          'EI': [3, 0, 0, 2],
          'SN': [5, 0, 0, 0],
          'TF': [5, 0, 0, 0],
          'JP': [5, 0, 0, 0],
        }),
      );
      final s = outcome.scored!;
      expect(s.axisScores['EI']!.positiveCount, 6);
      expect(s.axisScores['EI']!.negativeCount, 4);
      expect(s.axisPercents['EI'], 60); // 6/10
      expect(s.axisScores['EI']!.dominantPole, 'E');
    });

    test('16유형 전수 생성 — strong 단일 패턴으로도 16개 커버', () {
      final generated = <String>{};
      for (final ei in [
        [5, 0, 0, 0],
        [0, 0, 0, 5]
      ]) {
        for (final sn in [
          [5, 0, 0, 0],
          [0, 0, 0, 5]
        ]) {
          for (final tf in [
            [5, 0, 0, 0],
            [0, 0, 0, 5]
          ]) {
            for (final jp in [
              [5, 0, 0, 0],
              [0, 0, 0, 5]
            ]) {
              final o = scorer.score(
                content: wc,
                species: MbtiSpecies.dog,
                answers: _weightedAnswers(
                    wc, {'EI': ei, 'SN': sn, 'TF': tf, 'JP': jp}),
              );
              generated.add(o.scored!.typeCode);
            }
          }
        }
      }
      expect(generated.length, 16);
    });

    test('동점 폴백 — 가중 동점 + 문항수 동점 → 기본극(I·N·F·P)', () {
      // EI: mildA×1(1) + strongB 없음... 가중·문항 모두 같게 만들려면
      // strongA1(2)+mildA0 = A2 / strongB1(2) = B2, 문항 A1 B1 → 동점·동점 → I
      // 나머지 축은 한쪽 우세로 채움(축당 5 맞추기 위해 mild 로 보충).
      final outcome = scorer.score(
        content: wc,
        species: MbtiSpecies.dog,
        answers: _weightedAnswers(wc, {
          // strongA1(2)+mildA... 동점 만들기: A: strong1(2)+mild1(1)=3 / B: strong1(2)+mild1(1)=3
          // 문항 A2 B2 → 1문항 남음. 남은 1을 A mild 로 두면 A 우세가 됨.
          // 정확 동점: strongA1+mildA0 (=2, votes1) vs strongB1+mildB0(=2, votes1),
          // 남은 3문항은 mildA... → 안 됨. 대신 4문항만 쓰는 대신 5문항 동점 구성:
          // A: strong2(4) / B: strong2(4), 남은1 A mild(1) → A5 vs B4 (우세 A)
          // → 완전 동점은 5문항(홀수)에서 가중까지 같기 어렵다. 아래는 가중 동점:
          // A: strong1+mild1 = 3점(votes2) / B: strong1+mild1 = 3점(votes2), 남은1 = mildA(1) → A4 votes3
          // 홀수라 가중 동점+문항 동점 동시는 남은 1문항 때문에 불가 → 기본극 폴백은
          // 실데이터에선 짝수 가중으로만 발생. 여기선 4문항 축으로 별도 검증.
          'EI': [1, 1, 1, 1], // A: 2+1=3(votes2) / B: 1+2=3(votes2) → 5번째?
          'SN': [5, 0, 0, 0],
          'TF': [5, 0, 0, 0],
          'JP': [5, 0, 0, 0],
        }),
      );
      // [1,1,1,1] = 4문항만 → 5번째 문항 미응답이라 incompleteAnswers.
      // 동점 폴백은 단위로 직접 검증(아래 별도 test)하고, 여기선 가드 동작 확인.
      expect(outcome.isSuccess, isFalse);
      expect(outcome.error, MbtiScoringError.incompleteAnswers);
    });

    test('강도 누락 → invalidAnswer (강도 모드인데 intensity null)', () {
      final answers = _weightedAnswers(wc, {
        'EI': [5, 0, 0, 0],
        'SN': [5, 0, 0, 0],
        'TF': [5, 0, 0, 0],
        'JP': [5, 0, 0, 0],
      });
      // 한 응답의 intensity 를 제거
      final bad = [
        MbtiAnswer(questionId: answers.first.questionId, choice: 'A'),
        ...answers.skip(1),
      ];
      final outcome = scorer.score(
        content: wc,
        species: MbtiSpecies.dog,
        answers: bad,
      );
      expect(outcome.error, MbtiScoringError.invalidAnswer);
    });

    test('잘못된 강도 값 → invalidAnswer', () {
      final answers = _weightedAnswers(wc, {
        'EI': [5, 0, 0, 0],
        'SN': [5, 0, 0, 0],
        'TF': [5, 0, 0, 0],
        'JP': [5, 0, 0, 0],
      });
      final bad = [
        MbtiAnswer(
            questionId: answers.first.questionId,
            choice: 'A',
            intensity: 'medium'), // 정의 안 된 값
        ...answers.skip(1),
      ];
      final outcome = scorer.score(
        content: wc,
        species: MbtiSpecies.dog,
        answers: bad,
      );
      expect(outcome.error, MbtiScoringError.invalidAnswer);
    });
  });

  group('동점 폴백 직접 검증', () {
    // EI 축만 가변 문항 수, 나머지 3축은 1문항(명확 우세)로 채운 4축 콘텐츠.
    MbtiContent fourAxisContent(int eiQuestions) {
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
        final count = k == 'EI' ? eiQuestions : 1;
        for (int i = 0; i < count; i++) {
          qs.add(MbtiQuestion(
            id: '${k}_$i',
            axis: k,
            text: 'q',
            optionA: MbtiOption(label: 'A', pole: p[0]),
            optionB: MbtiOption(label: 'B', pole: p[1]),
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
        answerIntensities: const [
          MbtiIntensity(id: 'strong', label: 's', weight: 2),
          MbtiIntensity(id: 'mild', label: 'm', weight: 1),
        ],
      );
    }

    // SN/TF/JP 각 1문항에 양극(strong A) 응답 → S,T,J 우세(보조).
    List<MbtiAnswer> otherAxes() => const [
          MbtiAnswer(questionId: 'SN_0', choice: 'A', intensity: 'strong'),
          MbtiAnswer(questionId: 'TF_0', choice: 'A', intensity: 'strong'),
          MbtiAnswer(questionId: 'JP_0', choice: 'A', intensity: 'strong'),
        ];

    test('가중·문항 모두 동점(EI 4문항) → 기본극 neg(I)', () {
      final content = fourAxisContent(4);
      // EI: A strong1(2)+mild1(1)=3 votes2 / B strong1(2)+mild1(1)=3 votes2 → 완전 동점
      final answers = [
        const MbtiAnswer(questionId: 'EI_0', choice: 'A', intensity: 'strong'),
        const MbtiAnswer(questionId: 'EI_1', choice: 'A', intensity: 'mild'),
        const MbtiAnswer(questionId: 'EI_2', choice: 'B', intensity: 'strong'),
        const MbtiAnswer(questionId: 'EI_3', choice: 'B', intensity: 'mild'),
        ...otherAxes(),
      ];
      final outcome = const MbtiScorer()
          .score(content: content, species: MbtiSpecies.dog, answers: answers);
      expect(outcome.isSuccess, isTrue);
      expect(outcome.scored!.typeCode[0], 'I'); // EI 자리 기본극 폴백
    });

    test('가중 동점 + 문항 다수결로 결정 (EI 3문항, A votes 우세 → E)', () {
      final content = fourAxisContent(3);
      // EI: A mild1(1)+mild1(1)=2 votes2 / B strong1(2)=2 votes1 → 가중 동점 → 문항 다수결 E
      final answers = [
        const MbtiAnswer(questionId: 'EI_0', choice: 'A', intensity: 'mild'),
        const MbtiAnswer(questionId: 'EI_1', choice: 'A', intensity: 'mild'),
        const MbtiAnswer(questionId: 'EI_2', choice: 'B', intensity: 'strong'),
        ...otherAxes(),
      ];
      final outcome = const MbtiScorer()
          .score(content: content, species: MbtiSpecies.dog, answers: answers);
      expect(outcome.scored!.typeCode[0], 'E');
    });
  });
}
