import 'package:flutter/material.dart';
import '../../../../shared/themes/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../bloc/mbti_test_bloc.dart';
import '../theme/mbti_theme.dart';
import '../widgets/mbti_choice_card.dart';
import '../widgets/mbti_progress_bar.dart';
import '../widgets/mbti_scoring_view.dart';

/// 검사 플로우 호스트 페이지.
///
/// 단일 BLoC 을 소유하고 status 에 따라 인트로 → 문항 → 계산 연출을 전환한다.
/// 완료 시 결과 페이지로 이동(라우트는 작업 4 에서 결과 화면 연결).
class MbtiTestPage extends StatelessWidget {
  final String petId;
  final MbtiSpecies species;
  final String? petName;

  const MbtiTestPage({
    super.key,
    required this.petId,
    required this.species,
    this.petName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MbtiTestBloc>()
        ..add(MbtiTestStarted(petId: petId, species: species)),
      child: _MbtiTestView(petName: petName),
    );
  }
}

class _MbtiTestView extends StatelessWidget {
  final String? petName;

  const _MbtiTestView({this.petName});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MbtiTestBloc, MbtiTestState>(
      listenWhen: (p, c) =>
          p.status != c.status || p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.status == MbtiTestStatus.completed &&
            state.result != null) {
          // 결과 페이지로 교체 이동(작업 4 에서 결과 화면 구현·연결).
          context.pushReplacement('/mbti/result', extra: state.result);
        }
        if (state.errorMessage != null &&
            state.status == MbtiTestStatus.inProgress) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        // (세션6) 시스템 뒤로가기 처리:
        //  - scoring 중: 차단(연출 중 이탈 방지)
        //  - 문항 진행 중: 앱바 뒤로가기와 동일 — index>0이면 이전 문항,
        //    첫 문항이면 인트로(안내)로 복귀(진행상황 유지)
        //  - 그 외(인트로/이어하기 등): 기본 pop(이전 라우트로)
        final inProgress = state.status == MbtiTestStatus.inProgress;
        final canPop = state.status != MbtiTestStatus.scoring && !inProgress;
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (state.status == MbtiTestStatus.scoring) return; // 차단 유지
            if (inProgress) {
              _handleBackInProgress(context, state);
            }
          },
          child: Scaffold(
            backgroundColor: MbtiTheme.bg,
            appBar: _buildAppBar(context, state),
            body: SafeArea(
              child: switch (state.status) {
                MbtiTestStatus.loading ||
                MbtiTestStatus.initial =>
                  const Center(child: CircularProgressIndicator()),
                MbtiTestStatus.intro => _IntroView(
                    petName: petName,
                    species: state.species,
                    disclaimer: state.content?.disclaimer ?? '',
                    hasDraft: false,
                  ),
                MbtiTestStatus.resumePrompt => _IntroView(
                    petName: petName,
                    species: state.species,
                    disclaimer: state.content?.disclaimer ?? '',
                    hasDraft: true,
                    draftAnsweredCount:
                        state.pendingDraft?.answers.length ?? 0,
                    totalCount: state.totalQuestions,
                  ),
                MbtiTestStatus.inProgress => _QuestionView(state: state),
                MbtiTestStatus.scoring => MbtiScoringView(
                    onComplete: () {
                      // 연출 종료 시점: 결과가 준비되어 있으면 listener 가 이동 처리.
                      // 아직이면 completed 상태 도달 시 listener 가 이동.
                    },
                  ),
                MbtiTestStatus.completed =>
                  const Center(child: CircularProgressIndicator()),
                MbtiTestStatus.failure => _FailureView(
                    message: state.errorMessage ?? '문제가 발생했어요.',
                    onRetry: () => context
                        .read<MbtiTestBloc>()
                        .add(MbtiTestStarted(
                            petId: state.petId, species: state.species)),
                  ),
              },
            ),
          ),
        );
      },
    );
  }

  /// 문항 진행 중 뒤로가기 공통 처리(앱바 leading + 시스템 뒤로가기).
  /// index>0 → 이전 문항, 첫 문항(index 0) → 인트로(안내)로 복귀(진행상황 유지).
  void _handleBackInProgress(BuildContext context, MbtiTestState state) {
    if (state.currentIndex > 0) {
      context.read<MbtiTestBloc>().add(const MbtiPreviousPressed());
    } else {
      context.read<MbtiTestBloc>().add(const MbtiBackToIntro());
    }
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context, MbtiTestState state) {
    // 계산 연출 중에는 앱바 없이 몰입.
    if (state.status == MbtiTestStatus.scoring) return null;

    final isQuestion = state.status == MbtiTestStatus.inProgress;

    return AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () {
          // 문항 진행 중이면 시스템 뒤로가기와 동일 로직(이전 문항 → 첫 문항이면 인트로).
          // 그 외(인트로/이어하기 등) → 페이지 닫기.
          if (isQuestion) {
            _handleBackInProgress(context, state);
          } else {
            Navigator.of(context).maybePop();
          }
        },
      ),
      title: Text(
        '반려동물 MBTI',
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
      ),
      centerTitle: true,
      actions: [
        // (세션6 B) 문항 진행 중 홈으로 바로 나가기.
        // 진행상황은 BLoC draft에 자동 저장되어, 다음에 "이어서 하기"로 복귀 가능.
        // 확인 다이얼로그 없이 즉시 이동.
        if (isQuestion)
          IconButton(
            icon: const Icon(Icons.home_outlined, size: 22),
            tooltip: '홈으로',
            onPressed: () => context.go('/home'),
          ),
      ],
    );
  }
}

// ── 인트로 ────────────────────────────────────────────────

class _IntroView extends StatelessWidget {
  final String? petName;
  final MbtiSpecies species;
  final String disclaimer;
  final bool hasDraft;
  final int draftAnsweredCount;
  final int totalCount;

  const _IntroView({
    required this.petName,
    required this.species,
    required this.disclaimer,
    required this.hasDraft,
    this.draftAnsweredCount = 0,
    this.totalCount = 20,
  });

  @override
  Widget build(BuildContext context) {
    final name = (petName != null && petName!.trim().isNotEmpty)
        ? petName!.trim()
        : MbtiTheme.speciesLabel(species);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),
                Center(child: Icon(Icons.pets, size: 56.sp, color: AppTheme.textMuted)),
                SizedBox(height: 20.h),
                Text(
                  '$name의\n성격 유형을 알아볼까요?',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: MbtiTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  '평소 모습을 떠올리며 20개 질문에 답해 주세요.\n2~3분이면 충분해요.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    height: 1.5,
                    color: MbtiTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 20.h),
                // etc(범용) 안내 칩
                if (species == MbtiSpecies.etc) _genericChip(),
                if (species == MbtiSpecies.etc) SizedBox(height: 16.h),
                _infoCard(),
                SizedBox(height: 20.h),
                _disclaimerBox(),
              ],
            ),
          ),
        ),
        _bottomCta(context),
      ],
    );
  }

  Widget _genericChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: MbtiTheme.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 15.w, color: MbtiTheme.navy),
          SizedBox(width: 6.w),
          Text(
            '범용 문항 기반 결과예요',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: MbtiTheme.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    final items = [
      ('🗂️', '4가지 성향', '사교성 · 인식 · 관계 · 생활'),
      ('🎯', '16가지 유형', '우리 아이만의 캐릭터'),
      ('🤝', '찰떡 궁합', '잘 맞는 친구 추천'),
    ];
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Row(
              children: [
                Text(items[i].$1, style: TextStyle(fontSize: 22.sp)),
                SizedBox(width: 14.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items[i].$2,
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: MbtiTheme.textPrimary)),
                    SizedBox(height: 2.h),
                    Text(items[i].$3,
                        style: TextStyle(
                            fontSize: 12.sp, color: MbtiTheme.textSecondary)),
                  ],
                ),
              ],
            ),
            if (i < items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                child: const Divider(height: 1, color: AppTheme.neutral200),
              ),
          ],
        ],
      ),
    );
  }

  Widget _disclaimerBox() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: MbtiTheme.bg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.neutral200),
      ),
      child: Text(
        disclaimer,
        style: TextStyle(
          fontSize: 11.sp,
          height: 1.5,
          color: MbtiTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _bottomCta(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 20.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: hasDraft
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '진행하던 검사가 있어요 ($draftAnsweredCount/$totalCount)',
                  style: TextStyle(
                      fontSize: 13.sp, color: MbtiTheme.textSecondary),
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: () => context
                        .read<MbtiTestBloc>()
                        .add(const MbtiTestResumed()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MbtiTheme.navy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r)),
                    ),
                    child: Text('이어서 하기',
                        style: TextStyle(
                            fontSize: 16.sp, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: () => context
                      .read<MbtiTestBloc>()
                      .add(const MbtiTestRestarted()),
                  child: Text('처음부터 다시',
                      style: TextStyle(
                          fontSize: 14.sp, color: MbtiTheme.textSecondary)),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () => context
                    .read<MbtiTestBloc>()
                    .add(const MbtiTestRestarted()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MbtiTheme.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
                child: Text('검사 시작하기',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w600)),
              ),
            ),
    );
  }
}

// ── 문항 ──────────────────────────────────────────────────

class _QuestionView extends StatelessWidget {
  final MbtiTestState state;

  const _QuestionView({required this.state});

  @override
  Widget build(BuildContext context) {
    final q = state.currentQuestion;
    if (q == null) return const SizedBox.shrink();

    final number = state.currentIndex + 1;
    final selected = state.currentAnswer; // optionIndex
    final isLast = state.currentIndex >= state.totalQuestions - 1;

    // 문항의 options(4개)를 그대로 렌더. 배지는 인덱스 기반 A·B·C·D.
    const badges = ['A', 'B', 'C', 'D'];
    final options = q.options;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
          child: MbtiProgressBar(current: number, total: state.totalQuestions),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                Text(
                  'Q$number.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: MbtiTheme.coral,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  q.text,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: MbtiTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 24.h),
                for (int i = 0; i < options.length; i++) ...[
                  if (i > 0) SizedBox(height: 12.h),
                  MbtiChoiceCard(
                    badge: i < badges.length ? badges[i] : '${i + 1}',
                    label: options[i].label,
                    selected: selected?.optionIndex == i,
                    onTap: () =>
                        context.read<MbtiTestBloc>().add(MbtiAnswered(i)),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 마지막 문항 + 전부 응답 시 결과 보기 버튼.
        if (isLast)
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 20.h),
            child: SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: state.isComplete
                    ? () => context
                        .read<MbtiTestBloc>()
                        .add(const MbtiSubmitted())
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MbtiTheme.coral,
                  disabledBackgroundColor: AppTheme.neutral300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
                child: Text('결과 보기',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          )
        // (세션6) 마지막이 아니고 현재 문항에 이미 답이 있으면 "다음" 버튼.
        // 이전 문항으로 돌아와 같은 답을 유지하며 진행할 때 필요.
        // (답이 없을 때는 선택지를 누르면 자동으로 다음 문항으로 넘어가므로 불필요.)
        else if (selected != null)
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 20.h),
            child: SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () =>
                    context.read<MbtiTestBloc>().add(const MbtiNextPressed()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MbtiTheme.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
                child: Text('다음',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 실패 ──────────────────────────────────────────────────

class _FailureView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailureView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sentiment_dissatisfied,
                size: 56.w, color: MbtiTheme.textSecondary),
            SizedBox(height: 16.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.sp, color: MbtiTheme.textPrimary),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: MbtiTheme.navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
