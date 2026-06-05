import 'package:equatable/equatable.dart';

import 'quiz_content.dart';

/// 오늘 출제된 한 세트(진행 화면 입력).
///
/// [questions] 는 개인 순열에서 현재 커서로 끊어낸 문항들(보통 [QuizContent.dailyCount]
/// 개, 바퀴 끝이면 그보다 적을 수 있음). [cursor] 는 이 세트가 시작된 커서 위치로,
/// 세트 완료 커밋 시 `cursor += questions.length` 의 기준이 된다.
class QuizSet extends Equatable {
  /// 이 세트가 시작된 진행 커서(0부터).
  final int cursor;

  /// 출제 문항(순열 순서대로).
  final List<QuizQuestion> questions;

  const QuizSet({required this.cursor, required this.questions});

  int get length => questions.length;
  bool get isEmpty => questions.isEmpty;

  @override
  List<Object?> get props => [cursor, questions];
}
