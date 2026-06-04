import 'package:equatable/equatable.dart';

/// O/X 퀴즈 카테고리 정의 1개 (key + 표시 라벨).
///
/// 예: behavior → '행동·습성'. 진행 화면의 카테고리 칩에 [label] 을 노출한다.
class QuizCategory extends Equatable {
  final String key; // 'behavior' 등 (question.category 의 키)
  final String label; // '행동·습성' 등 표시용

  const QuizCategory({required this.key, required this.label});

  @override
  List<Object?> get props => [key, label];
}

/// O/X 퀴즈 문항 1개.
///
/// 정답이 있는 콘텐츠지만(O/X) 보상은 1차 미적립. species 는 종 태그(dog/cat/common)
/// 로 진행 화면 칩에만 쓰이며 출제 분기에는 영향이 없다(일반 상식 퀴즈, 사용자 1인 기준).
class QuizQuestion extends Equatable {
  final String id; // 'behavior_01' 등 (고유)
  final String category; // 'behavior' 등 (categories 의 key)
  final String species; // 'dog' | 'cat' | 'common'
  final String statement; // 진술문
  final String answer; // 'O' | 'X'
  final String explain; // 한 줄 해설

  const QuizQuestion({
    required this.id,
    required this.category,
    required this.species,
    required this.statement,
    required this.answer,
    required this.explain,
  });

  /// 정답이 O 인지 여부(버튼 정오 비교용).
  bool get isAnswerO => answer == 'O';

  @override
  List<Object?> get props => [id, category, species, statement, answer, explain];
}

/// 앱 번들 O/X 퀴즈 콘텐츠 전체 (`assets/data/pet_quiz_content_v{N}.json`).
///
/// 외부 호출 0 · DB 0. 출제는 이 270문항 + 개인 시드(quiz_seed)로 만든 순열을
/// 커서로 끊어 쓰는 방식이라, 콘텐츠 자체는 불변 데이터다.
class QuizContent extends Equatable {
  final int version;

  /// 하루 출제 문항 수(=4). 한 세트 크기·커서 전진 단위.
  final int dailyCount;

  /// 결과 화면 하단 고정 면책 문구.
  final String disclaimer;

  final List<QuizCategory> categories;

  /// 전체 문항 풀(원본 순서 고정 — 개인 순열은 인덱스로 계산).
  final List<QuizQuestion> questions;

  const QuizContent({
    required this.version,
    required this.dailyCount,
    required this.disclaimer,
    required this.categories,
    required this.questions,
  });

  /// 카테고리 key → label 조회(없으면 key 그대로 폴백).
  String labelOfCategory(String key) {
    for (final c in categories) {
      if (c.key == key) return c.label;
    }
    return key;
  }

  @override
  List<Object?> get props =>
      [version, dailyCount, disclaimer, categories, questions];
}
