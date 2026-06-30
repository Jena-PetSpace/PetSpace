part of 'mbti_test_bloc.dart';

abstract class MbtiTestEvent extends Equatable {
  const MbtiTestEvent();

  @override
  List<Object?> get props => [];
}

/// 검사 시작: 콘텐츠 로드 + 종 확정 + 저장된 이어하기 스냅샷 확인.
class MbtiTestStarted extends MbtiTestEvent {
  final String petId;
  final MbtiSpecies species;

  const MbtiTestStarted({required this.petId, required this.species});

  @override
  List<Object?> get props => [petId, species];
}

/// 인트로에서 "이어하기" 선택 → 저장된 스냅샷으로 복원.
class MbtiTestResumed extends MbtiTestEvent {
  const MbtiTestResumed();
}

/// 인트로에서 "처음부터" 선택 → 스냅샷 삭제 후 첫 문항부터.
class MbtiTestRestarted extends MbtiTestEvent {
  const MbtiTestRestarted();
}

/// 현재 문항에 답함(옵션 인덱스 0~3). 자동 다음 문항 이동 + 임시저장.
class MbtiAnswered extends MbtiTestEvent {
  final int optionIndex;

  const MbtiAnswered(this.optionIndex);

  @override
  List<Object?> get props => [optionIndex];
}

/// 이전 문항으로.
class MbtiPreviousPressed extends MbtiTestEvent {
  const MbtiPreviousPressed();
}

/// 다음 문항으로(답 변경 없이 이동만). 이전 문항으로 돌아와 이미 답이 있는 상태에서
/// 같은 답을 유지하며 진행할 때 사용. 마지막 문항이면 무시.
class MbtiNextPressed extends MbtiTestEvent {
  const MbtiNextPressed();
}

/// 문항에서 인트로(안내) 화면으로 복귀. 첫 문항에서 뒤로가기 시 사용.
/// 진행상황(draft)은 유지되어 인트로에서 "이어서 하기"로 복귀 가능.
class MbtiBackToIntro extends MbtiTestEvent {
  const MbtiBackToIntro();
}

/// 마지막 문항까지 응답 완료 → 가드 검사 후 채점.
class MbtiSubmitted extends MbtiTestEvent {
  const MbtiSubmitted();
}
