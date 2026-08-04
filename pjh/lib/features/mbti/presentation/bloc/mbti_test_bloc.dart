import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../data/datasources/mbti_content_data_source.dart';
import '../../data/datasources/mbti_draft_local_data_source.dart';
import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../../domain/repositories/mbti_repository.dart';
import '../../domain/services/mbti_scorer.dart';
import '../../domain/usecases/save_mbti_result.dart';

part 'mbti_test_event.dart';
part 'mbti_test_state.dart';

/// 첫 검사 완료 보상.
const int kMbtiFirstTestPoints = 30;
const String kMbtiExplorerBadgeId = 'mbti_explorer';

/// 검사 플로우 BLoC.
///
/// 콘텐츠 로드 → 종 확정 → 이어하기 확인 → 문항 진행(응답마다 임시저장) →
/// 가드 검사 → 채점 → 결과 저장 → 임시저장 정리.
class MbtiTestBloc extends Bloc<MbtiTestEvent, MbtiTestState> {
  final MbtiContentDataSource contentDataSource;
  final MbtiDraftLocalDataSource draftDataSource;
  final MbtiScorer scorer;
  final SaveMbtiResult saveMbtiResult;
  final MbtiRepository mbtiRepository;
  final SocialRepository socialRepository;

  MbtiTestBloc({
    required this.contentDataSource,
    required this.draftDataSource,
    required this.scorer,
    required this.saveMbtiResult,
    required this.mbtiRepository,
    required this.socialRepository,
  }) : super(const MbtiTestState()) {
    on<MbtiTestStarted>(_onStarted);
    on<MbtiTestResumed>(_onResumed);
    on<MbtiTestRestarted>(_onRestarted);
    on<MbtiAnswered>(_onAnswered);
    on<MbtiPreviousPressed>(_onPrevious);
    on<MbtiNextPressed>(_onNext);
    on<MbtiBackToIntro>(_onBackToIntro);
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
        // 인트로 노출(검사 시작 전). "검사 시작하기" 누르면 inProgress 로 전환.
        emit(state.copyWith(
          status: MbtiTestStatus.intro,
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

  // 분석: 검사 시작/완주/이탈 판정용 플래그.
  bool _startLogged = false;
  bool _completedOrAbandonLogged = false;

  void _logStartOnce() {
    if (_startLogged) return;
    _startLogged = true;
    AnalyticsService.instance.logMbtiStart(species: state.species.key);
  }

  void _onResumed(MbtiTestResumed event, Emitter<MbtiTestState> emit) {
    _logStartOnce();
    final draft = state.pendingDraft;
    if (draft == null) {
      emit(state.copyWith(status: MbtiTestStatus.inProgress));
      return;
    }
    final answers = {for (final a in draft.answers) a.questionId: a};
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
    _logStartOnce();
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

    final answers = Map<String, MbtiAnswer>.from(state.answers)
      ..[q.id] = MbtiAnswer(
        questionId: q.id,
        optionIndex: event.optionIndex,
      );

    final isLast = state.currentIndex >= state.totalQuestions - 1;
    final nextIndex = isLast ? state.currentIndex : state.currentIndex + 1;

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

  /// 다음 문항으로(답 변경 없이 이동만). 이전 문항으로 돌아와 이미 답이 있을 때
  /// 같은 답을 유지하며 진행. 마지막 문항이면 무시.
  Future<void> _onNext(
      MbtiNextPressed event, Emitter<MbtiTestState> emit) async {
    if (state.currentIndex >= state.totalQuestions - 1) return;
    final nextIndex = state.currentIndex + 1;
    emit(state.copyWith(currentIndex: nextIndex));
    await _persistDraft(answers: state.answers, currentIndex: nextIndex);
  }

  /// 문항 → 인트로(안내) 복귀. 첫 문항에서 뒤로가기 시 사용.
  /// 진행 중 응답이 있으면 resumePrompt(이어하기 제안)로 보내 "이어서 하기"를 노출하고,
  /// 응답이 없으면 일반 intro로 보낸다. draft도 그대로 남아 복귀 가능.
  void _onBackToIntro(MbtiBackToIntro event, Emitter<MbtiTestState> emit) {
    final content = state.content;
    if (state.answers.isEmpty || content == null) {
      emit(state.copyWith(status: MbtiTestStatus.intro));
      return;
    }
    final draft = MbtiDraft(
      petId: state.petId,
      species: state.species,
      contentVersion: content.version,
      currentIndex: state.currentIndex,
      answers: state.answers.values.toList(),
    );
    emit(state.copyWith(
      status: MbtiTestStatus.resumePrompt,
      pendingDraft: draft,
    ));
  }

  Future<void> _onSubmitted(
      MbtiSubmitted event, Emitter<MbtiTestState> emit) async {
    final content = state.content;
    if (content == null) return;

    final answerList = state.answers.values.toList();

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

    // 보상 게이팅: "그 pet 의 첫 결과일 때만" 지급.
    // 저장 전에 기존 결과 유무를 확인(insert 누적 구조라 저장 후엔 항상 ≥1).
    // 조회 실패 시 보수적으로 첫 검사 아님으로 간주(중복 적립 방지 우선).
    final priorResult = await mbtiRepository.getLatestResult(state.petId);
    final isFirstForPet = priorResult.fold((_) => false, (r) => r == null);

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
          errorMessage: publicErrorMessage(
            failure.message,
            fallback: ErrorMessages.mbtiResultSaveFailed,
          ),
        ));
      },
      (saved) async {
        // 결과 저장 성공 → 임시 스냅샷 정리(다음에 엉뚱한 이어하기 방지).
        await draftDataSource.clearDraft(state.petId);

        // 완주 분석(익명 집계) — 저장 성공 후 1회.
        if (!_completedOrAbandonLogged) {
          _completedOrAbandonLogged = true;
          AnalyticsService.instance.logMbtiComplete(
            species: state.species.key,
            typeCode: saved.typeCode,
          );
        }

        // 보상: pet 첫 결과일 때만(저장 성공 후). 둘째 검사부턴 결과만 갱신.
        bool granted = false;
        if (isFirstForPet) {
          granted = await _grantFirstTestReward();
        }

        emit(state.copyWith(
          status: MbtiTestStatus.completed,
          result: saved,
          rewardGranted: granted,
          clearPendingDraft: true,
        ));
      },
    );
  }

  /// 첫 검사 보상 지급(포인트 + 뱃지). 실패해도 결과 완료를 막지 않는다.
  /// 뱃지는 멱등(이미 있으면 중복 안 됨). 반환: 포인트 지급 시도 성공 여부.
  Future<bool> _grantFirstTestReward() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return false;
      await socialRepository.incrementUserPoints(
        userId: userId,
        points: kMbtiFirstTestPoints,
      );
      await socialRepository.awardBadgeIfAbsent(
        userId: userId,
        badgeId: kMbtiExplorerBadgeId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() {
    // 완주/실패 없이 검사 화면을 떠나면 이탈로 집계(시작했고, 아직 미완료일 때).
    if (_startLogged &&
        !_completedOrAbandonLogged &&
        state.status == MbtiTestStatus.inProgress) {
      _completedOrAbandonLogged = true;
      AnalyticsService.instance.logMbtiAbandon(
        species: state.species.key,
        answered: state.answers.length,
        total: state.totalQuestions,
      );
    }
    return super.close();
  }

  Future<void> _persistDraft({
    required Map<String, MbtiAnswer> answers,
    required int currentIndex,
  }) async {
    final content = state.content;
    if (content == null) return;
    final draft = MbtiDraft(
      petId: state.petId,
      species: state.species,
      contentVersion: content.version,
      currentIndex: currentIndex,
      answers: answers.values.toList(),
    );
    await draftDataSource.saveDraft(draft);
  }
}
