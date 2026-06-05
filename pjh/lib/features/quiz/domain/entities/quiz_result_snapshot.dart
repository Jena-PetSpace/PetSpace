import 'package:equatable/equatable.dart';

/// 오늘 푼 한 문항의 복기 스냅샷 1개.
///
/// 정답 여부를 재계산하지 않고 그대로 저장한다(콘텐츠 버전이 바뀌어도 그날 본 그대로
/// 복기되도록). [chosen] 은 사용자가 고른 'O'/'X', [answer] 는 정답.
class QuizAnswerSnapshot extends Equatable {
  final String qId;
  final String statement;
  final String chosen; // 'O' | 'X'
  final String answer; // 'O' | 'X' (정답)
  final String explain;

  const QuizAnswerSnapshot({
    required this.qId,
    required this.statement,
    required this.chosen,
    required this.answer,
    required this.explain,
  });

  bool get isCorrect => chosen == answer;

  Map<String, dynamic> toJson() => {
        'qId': qId,
        'statement': statement,
        'chosen': chosen,
        'answer': answer,
        'explain': explain,
      };

  factory QuizAnswerSnapshot.fromJson(Map<String, dynamic> j) =>
      QuizAnswerSnapshot(
        qId: j['qId'] as String? ?? '',
        statement: j['statement'] as String? ?? '',
        chosen: j['chosen'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        explain: j['explain'] as String? ?? '',
      );

  @override
  List<Object?> get props => [qId, statement, chosen, answer, explain];
}

/// 오늘 세트 결과 복기 스냅샷(완료 1회당 1개).
///
/// 완료 카드 탭 시 이 스냅샷을 읽어 결과/복기 화면을 재계산 없이 그린다.
/// `quiz_today_result_<YYYYMMDD>` 에 JSON 1칸으로 저장.
class QuizResultSnapshot extends Equatable {
  final String dateKey; // 'YYYYMMDD'
  final int correctCount;
  final int total;
  final List<QuizAnswerSnapshot> answers;

  const QuizResultSnapshot({
    required this.dateKey,
    required this.correctCount,
    required this.total,
    required this.answers,
  });

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'correctCount': correctCount,
        'total': total,
        'answers': answers.map((a) => a.toJson()).toList(),
      };

  factory QuizResultSnapshot.fromJson(Map<String, dynamic> j) =>
      QuizResultSnapshot(
        dateKey: j['dateKey'] as String? ?? '',
        correctCount: (j['correctCount'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        answers: (j['answers'] as List?)
                ?.whereType<Map>()
                .map((m) =>
                    QuizAnswerSnapshot.fromJson(m.cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [dateKey, correctCount, total, answers];
}
