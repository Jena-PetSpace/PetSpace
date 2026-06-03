part of 'mbti_test_bloc.dart';

enum MbtiTestStatus {
  initial,
  loading, // 콘텐츠 로딩
  resumePrompt, // 이어하기 제안 (저장된 스냅샷 있음)
  inProgress, // 문항 진행 중
  scoring, // 계산 연출 중
  completed, // 채점·저장 완료
  failure, // 로드/저장 실패
}

class MbtiTestState extends Equatable {
  final MbtiTestStatus status;
  final String petId;
  final MbtiSpecies species;
  final MbtiContent? content;

  /// q_id → choice('A'/'B'). 진행 중 응답 누적.
  final Map<String, String> answers;

  /// 현재 보고 있는 문항 인덱스(0-based).
  final int currentIndex;

  /// 저장된 이어하기 스냅샷(resumePrompt 단계에서만 채워짐).
  final MbtiDraft? pendingDraft;

  /// 채점 완료 결과(저장된 서버 결과). completed 단계에서 채워짐.
  final PetMbtiResult? result;

  /// 이번 완료가 그 pet 의 첫 검사라 보상(포인트+뱃지)이 지급됐는지.
  final bool rewardGranted;

  final String? errorMessage;

  const MbtiTestState({
    this.status = MbtiTestStatus.initial,
    this.petId = '',
    this.species = MbtiSpecies.etc,
    this.content,
    this.answers = const {},
    this.currentIndex = 0,
    this.pendingDraft,
    this.result,
    this.rewardGranted = false,
    this.errorMessage,
  });

  List<MbtiQuestion> get questions => content?.questionsFor(species) ?? const [];

  int get totalQuestions => questions.length;

  MbtiQuestion? get currentQuestion =>
      (currentIndex >= 0 && currentIndex < questions.length)
          ? questions[currentIndex]
          : null;

  /// 현재 문항에 이미 선택한 답(있으면).
  String? get currentChoice {
    final q = currentQuestion;
    if (q == null) return null;
    return answers[q.id];
  }

  /// 모든 문항에 응답 완료했는지(가드의 UI 측 사전 체크).
  bool get isComplete =>
      totalQuestions > 0 && answers.length == totalQuestions;

  /// 진행률 (0.0 ~ 1.0). "5/20" 표시는 currentIndex 기반.
  double get progress =>
      totalQuestions == 0 ? 0 : (currentIndex) / totalQuestions;

  MbtiTestState copyWith({
    MbtiTestStatus? status,
    String? petId,
    MbtiSpecies? species,
    MbtiContent? content,
    Map<String, String>? answers,
    int? currentIndex,
    MbtiDraft? pendingDraft,
    bool clearPendingDraft = false,
    PetMbtiResult? result,
    bool? rewardGranted,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MbtiTestState(
      status: status ?? this.status,
      petId: petId ?? this.petId,
      species: species ?? this.species,
      content: content ?? this.content,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      pendingDraft:
          clearPendingDraft ? null : (pendingDraft ?? this.pendingDraft),
      result: result ?? this.result,
      rewardGranted: rewardGranted ?? this.rewardGranted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        petId,
        species,
        content,
        answers,
        currentIndex,
        pendingDraft,
        result,
        rewardGranted,
        errorMessage,
      ];
}
