import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/mbti_content_data_source.dart';
import '../../data/datasources/mbti_draft_local_data_source.dart';
import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../../domain/services/mbti_scorer.dart';
import '../../domain/usecases/save_mbti_result.dart';

part 'mbti_test_event.dart';
part 'mbti_test_state.dart';

/// 검사 플로우 BLoC.
///
/// 콘텐츠 로드 → 종 확정 → 이어하기 확인 → 문항 진행(응답마다 임시저장) →
/// 가드 검사 → 채점 → 결과 저장 → 임시저장 정리.
class MbtiTestBloc extends Bloc<MbtiTestEvent, MbtiTestState> {
  final MbtiContentDataSource contentDataSource;
  final MbtiDraftLocalDataSource draftDataSource;
  final MbtiScorer scorer;
  final SaveMbtiResult saveMbtiResult;

  MbtiTestBloc({
    required this.contentDataSource,
    required this.draftDataSource,
    required this.scorer,
    required this.saveMbtiResult,
  }) : super(const MbtiTestState()) {
    on<MbtiTestStarted>(_onStarted);
    on<MbtiTestResumed>(_onResumed);
    on<MbtiTestRestarted>(_onRestarted);
    on<MbtiAnswered>(_onAnswered);
    on<MbtiPreviousPressed>(_onPrevious);
    on<MbtiSubmitted>(_onSubmitted);
  }

  Future<void> _onStarted(
      MbtiTestStarted event, Emitter<MbtiTestState> emit) async {
    emit(state.copyWith(
      status: MbtiTestStatus.loading,
      petId: event.petId,
      species: event.species,
      clearError: true,
    ));

    try {
      final content = await contentDataSource.loadContent();

      // 이어하기 스냅샷 확인(버전 불일치면 데이터소스가 폐기 후 null 반환).
      final draft = await draftDataSource.loadDraft(
        event.petId,
        expectedContentVersion: content.version,
      );

      // 스냅샷의 종이 현재 종과 다르면(프로필 종 변경 등) 이어하기 폐기.
      final usableDraft =
          (draft != null && draft.species == event.species) ? draft : null;
      if (draft != null && usableDraft == null) {
        await draftDataSource.clearDraft(event.petId);
      }

      if (usableDraft != null && usableDraft.answers.isNotEmpty) {
        emit(state.copyWith(
          status: MbtiTestStatus.resumePrompt,
          content: content,
          pendingDraft: usableDraft,
        ));
      } else {
        emit(state.copyWith(
          status: MbtiTestStatus.inProgress,
          content: content,
          answers: const {},
          currentIndex: 0,
          clearPendingDraft: true,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: MbtiTestStatus.failure,
        errorMessage: '검사를 시작하지 못했어요. 잠시 후 다시 시도해 주세요.',
      ));
    }
  }

  void _onResumed(MbtiTestResumed event, Emitter<MbtiTestState> emit) {
    final draft = state.pendingDraft;
    if (draft == null) {
      emit(state.copyWith(status: MbtiTestStatus.inProgress));
      return;
    }
    final answers = {for (final a in draft.answers) a.questionId: a.choice};
    final total = state.questions.length;
    // 이어하기 진입 위치: 저장된 인덱스(범위 보정).
    final idx = draft.currentIndex.clamp(0, total > 0 ? total - 1 : 0);

    emit(state.copyWith(
      status: MbtiTestStatus.inProgress,
      answers: answers,
      currentIndex: idx,
      clearPendingDraft: true,
    ));
  }

  Future<void> _onRestarted(
      MbtiTestRestarted event, Emitter<MbtiTestState> emit) async {
    // "처음부터 다시" → 스냅샷 삭제(엉뚱한 이어하기 방지) 후 첫 문항부터.
    await draftDataSource.clearDraft(state.petId);
    emit(state.copyWith(
      status: MbtiTestStatus.inProgress,
      answers: const {},
      currentIndex: 0,
      clearPendingDraft: true,
    ));
  }

  Future<void> _onAnswered(
      MbtiAnswered event, Emitter<MbtiTestState> emit) async {
    final q = state.currentQuestion;
    if (q == null) return;

    final answers = Map<String, String>.from(state.answers)
      ..[q.id] = event.choice;

    final isLast = state.currentIndex >= state.totalQuestions - 1;
    final nextIndex =
        isLast ? state.currentIndex : state.currentIndex + 1;

    emit(state.copyWith(answers: answers, currentIndex: nextIndex));

    // 응답마다 임시저장(중간 이탈 대비).
    await _persistDraft(answers: answers, currentIndex: nextIndex);
  }

  Future<void> _onPrevious(
      MbtiPreviousPressed event, Emitter<MbtiTestState> emit) async {
    if (state.currentIndex <= 0) return;
    final prevIndex = state.currentIndex - 1;
    emit(state.copyWith(currentIndex: prevIndex));
    await _persistDraft(answers: state.answers, currentIndex: prevIndex);
  }

  Future<void> _onSubmitted(
      MbtiSubmitted event, Emitter<MbtiTestState> emit) async {
    final content = state.content;
    if (content == null) return;

    final answerList = state.answers.entries
        .map((e) => MbtiAnswer(questionId: e.key, choice: e.value))
        .toList();

    // 가드: 채점기가 "20문항 전부 응답" 충족 여부를 판정. 미충족이면 채점 안 함.
    final outcome = scorer.score(
      content: content,
      species: state.species,
      answers: answerList,
    );

    if (!outcome.isSuccess) {
      // 결과 화면 진입 차단 — 진행 상태 유지(사용자가 누락 문항 마저 응답).
      emit(state.copyWith(
        status: MbtiTestStatus.inProgress,
        errorMessage: '아직 답하지 않은 문항이 있어요. 모든 문항에 답해 주세요.',
      ));
      return;
    }

    emit(state.copyWith(status: MbtiTestStatus.scoring, clearError: true));

    final scored = outcome.scored!;
    final entity = PetMbtiResult(
      id: '', // 서버 생성
      petId: state.petId,
      species: state.species,
      typeCode: scored.typeCode,
      axisScores: scored.axisScores,
      answers: answerList,
      contentVersion: scored.contentVersion,
      createdAt: DateTime.now(),
    );

    final saveResult =
        await saveMbtiResult(SaveMbtiResultParams(result: entity));

    await saveResult.fold(
      (failure) async {
        emit(state.copyWith(
          status: MbtiTestStatus.failure,
          errorMessage: failure.message,
        ));
      },
      (saved) async {
        // 결과 저장 성공 → 임시 스냅샷 정리(다음에 엉뚱한 이어하기 방지).
        await draftDataSource.clearDraft(state.petId);
        emit(state.copyWith(
          status: MbtiTestStatus.completed,
          result: saved,
          clearPendingDraft: true,
        ));
      },
    );
  }

  Future<void> _persistDraft({
    required Map<String, String> answers,
    required int currentIndex,
  }) async {
    final content = state.content;
    if (content == null) return;
    final draft = MbtiDraft(
      petId: state.petId,
      species: state.species,
      contentVersion: content.version,
      currentIndex: currentIndex,
      answers: answers.entries
          .map((e) => MbtiAnswer(questionId: e.key, choice: e.value))
          .toList(),
    );
    await draftDataSource.saveDraft(draft);
  }
}
