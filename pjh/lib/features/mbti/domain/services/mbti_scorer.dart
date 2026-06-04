import '../entities/mbti_content.dart';
import '../entities/pet_mbti_result.dart';

/// 채점 축 순서 — type_code 글자 순서를 결정한다 (EI→SN→TF→JP).
const List<String> kMbtiAxisOrder = ['EI', 'SN', 'TF', 'JP'];

/// 채점 실패 사유.
enum MbtiScoringError {
  /// 응답 수가 문항 수와 불일치(중간 이탈/누락 등) — 채점 불가.
  incompleteAnswers,

  /// 알 수 없는 q_id 또는 잘못된 choice 가 포함됨.
  invalidAnswer,

  /// 한 축에 응답이 0개여서 우세 극을 정할 수 없음.
  emptyAxis,
}

/// 채점 결과 래퍼. 성공 시 [scored], 실패 시 [error] 중 하나만 채워진다.
class MbtiScoringOutcome {
  final ScoredMbti? scored;
  final MbtiScoringError? error;
  final String? message;

  const MbtiScoringOutcome._({this.scored, this.error, this.message});

  factory MbtiScoringOutcome.success(ScoredMbti scored) =>
      MbtiScoringOutcome._(scored: scored);

  factory MbtiScoringOutcome.failure(MbtiScoringError error, String message) =>
      MbtiScoringOutcome._(error: error, message: message);

  bool get isSuccess => scored != null;
}

/// 채점 산출물.
///
/// - [typeCode] 는 **단순 다수결(우세 극)** 로만 결정된다.
/// - [axisScores] 는 원점수(극별 카운트)로 DB 에 그대로 보존된다.
/// - [axisPercents] 는 **표시 전용** (우세 60/80/100, 열세 40/20/0). type_code
///   결정에는 쓰이지 않으며, 신뢰도/정확도 수치로 노출하지 않는다.
class ScoredMbti {
  final String typeCode;
  final Map<String, AxisScore> axisScores;
  final Map<String, int> axisPercents; // 표시용 우세 극 퍼센트 (축 key → %)
  final int contentVersion;

  const ScoredMbti({
    required this.typeCode,
    required this.axisScores,
    required this.axisPercents,
    required this.contentVersion,
  });
}

/// MBTI 채점기.
///
/// 항상 전달된 [content] (= 저장된 content_version 의 문항 세트) 기준으로
/// 응답을 해석한다. 과거 결과 복기 시에도 해당 버전 content 를 넘기면 된다.
class MbtiScorer {
  const MbtiScorer();

  /// [species] 문항 세트 + [answers] 로 채점.
  ///
  /// 가드: 해당 종 문항 전부에 대해 유효한 응답이 정확히 1:1 로 존재해야 한다.
  /// (중간 이탈/누락으로 일부만 응답되면 [MbtiScoringError.incompleteAnswers].)
  MbtiScoringOutcome score({
    required MbtiContent content,
    required MbtiSpecies species,
    required List<MbtiAnswer> answers,
  }) {
    final questions = content.questionsFor(species);
    final questionById = {for (final q in questions) q.id: q};
    // 강도 모드 여부(콘텐츠에 answerIntensities 정의가 있으면 강도 응답 요구).
    final usesIntensity = content.answerIntensities.isNotEmpty;
    final validIntensityIds =
        content.answerIntensities.map((i) => i.id).toSet();

    // 응답을 q_id 로 정리(마지막 응답 우선). 중복/미지의 id 검출.
    final answerByQid = <String, MbtiAnswer>{};
    for (final a in answers) {
      if (!questionById.containsKey(a.questionId)) {
        return MbtiScoringOutcome.failure(
          MbtiScoringError.invalidAnswer,
          '알 수 없는 문항: ${a.questionId}',
        );
      }
      if (a.choice != 'A' && a.choice != 'B') {
        return MbtiScoringOutcome.failure(
          MbtiScoringError.invalidAnswer,
          '잘못된 선택: ${a.questionId}=${a.choice}',
        );
      }
      // 강도 모드면 intensity 가 정의된 값('strong'/'mild')이어야 한다.
      if (usesIntensity &&
          (a.intensity == null || !validIntensityIds.contains(a.intensity))) {
        return MbtiScoringOutcome.failure(
          MbtiScoringError.invalidAnswer,
          '잘못된 강도: ${a.questionId}=${a.intensity}',
        );
      }
      answerByQid[a.questionId] = a;
    }

    // 가드: 모든 문항이 정확히 응답되었는지(20문항 전부).
    if (answerByQid.length != questions.length) {
      return MbtiScoringOutcome.failure(
        MbtiScoringError.incompleteAnswers,
        '응답 누락: ${answerByQid.length}/${questions.length} 문항만 응답됨',
      );
    }

    // 축별 가중 점수 집계.
    final axisScores = <String, AxisScore>{};
    final codeBuffer = StringBuffer();

    for (final axisKey in kMbtiAxisOrder) {
      final axis = content.axes[axisKey];
      if (axis == null) {
        return MbtiScoringOutcome.failure(
          MbtiScoringError.invalidAnswer,
          '콘텐츠에 축 정의 없음: $axisKey',
        );
      }
      final pos = axis.posCode;
      final neg = axis.negCode;
      // 가중 점수(weight 합산) + 문항 수(동점 폴백용 다수결).
      int posScore = 0;
      int negScore = 0;
      int posVotes = 0;
      int negVotes = 0;

      for (final q in questions.where((q) => q.axis == axisKey)) {
        final ans = answerByQid[q.id]!;
        final pole = q.poleForChoice(ans.choice);
        final weight = content.weightForIntensity(ans.intensity);
        if (pole == pos) {
          posScore += weight;
          posVotes++;
        } else if (pole == neg) {
          negScore += weight;
          negVotes++;
        }
      }

      if (posScore + negScore == 0) {
        return MbtiScoringOutcome.failure(
          MbtiScoringError.emptyAxis,
          '축 $axisKey 에 응답 없음',
        );
      }

      // axis_scores 에는 극별 가중 점수를 보존(예: {"EI":{"E":7,"I":3}}).
      final score = AxisScore(
        positivePole: pos,
        negativePole: neg,
        positiveCount: posScore,
        negativeCount: negScore,
      );
      axisScores[axisKey] = score;

      // type_code 우세 극 결정:
      //  1순위 가중 점수 → 2순위(동점 시) 문항 수 다수결 →
      //  3순위(그래도 동점) 축 기본극(neg = I/N/F/P).
      final String dominant;
      if (posScore != negScore) {
        dominant = posScore > negScore ? pos : neg;
      } else if (posVotes != negVotes) {
        dominant = posVotes > negVotes ? pos : neg;
      } else {
        dominant = neg; // 기본극 폴백 (I·N·F·P)
      }
      codeBuffer.write(dominant);
    }

    // 퍼센트는 표시 전용으로 별도 산출 (type_code 결정과 분리).
    final axisPercents = <String, int>{
      for (final entry in axisScores.entries)
        entry.key: entry.value.dominantPercent,
    };

    return MbtiScoringOutcome.success(ScoredMbti(
      typeCode: codeBuffer.toString(),
      axisScores: axisScores,
      axisPercents: axisPercents,
      contentVersion: content.version,
    ));
  }
}
