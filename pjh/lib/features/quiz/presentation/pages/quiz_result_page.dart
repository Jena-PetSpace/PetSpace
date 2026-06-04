import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../data/datasources/quiz_content_data_source.dart';
import '../../data/datasources/quiz_local_data_source.dart';
import '../../domain/services/quiz_reward_hook.dart';
import '../../domain/services/quiz_session_builder.dart';
import '../theme/quiz_theme.dart';

/// O/X 퀴즈 결과 화면.
///
/// 진행 화면에서 4문제(바퀴 끝이면 잔여)를 다 풀면 pushReplacement 로 진입한다.
/// **여기가 로컬 상태가 실제로 쓰여지는 유일한 지점**:
/// - 완주(세트 완료) 1회당 커밋 1회: `cursor += 푼 개수`(완주 시 재셔플+0) +
///   `quiz_done_<오늘>` + 스트릭 day-diff 갱신을 원자적으로(작업1 `commitSetCompletion`).
/// - **멱등**: 이미 오늘 done 이면 재커밋·재적립 안 함(재진입·새로고침 안전).
/// - 커밋 직후 `onQuizCompleted(correct,total,streak)` 훅 1회(1차 no-op).
///
/// 정답 수는 화면에서만 표시(저장 안 함 — 스펙대로 그 자리에서만 보여줌).
class QuizResultPage extends StatefulWidget {
  final int correct;
  final int total;
  final String dateKey; // 'YYYYMMDD' (로컬)

  const QuizResultPage({
    super.key,
    required this.correct,
    required this.total,
    required this.dateKey,
  });

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {
  late final Future<_ResultVM> _future;

  @override
  void initState() {
    super.initState();
    _future = _commitAndLoad();
  }

  /// 커밋(멱등) + 스트릭 산출 + 훅 호출 + 면책 문구 로드.
  Future<_ResultVM> _commitAndLoad() async {
    final local = sl<QuizLocalDataSource>();
    final builder = sl<QuizSessionBuilder>();
    final content = await sl<QuizContentDataSource>().loadContent();

    // 이미 오늘 완료면 재커밋 금지(멱등). 신규 완주일 때만 커밋+훅.
    final alreadyDone = await local.isDoneToday(widget.dateKey);

    int streak;
    if (alreadyDone) {
      // 재진입/새로고침: 커서·done·스트릭 불변. 현재 스트릭만 읽어 표시.
      streak = await local.getStreak();
    } else {
      // 신규 완주: 원자적 커밋(커서 전진·완주 시 재셔플+0·done 기록·스트릭 갱신).
      streak = await builder.commitCompletion(
        dateKey: widget.dateKey,
        solvedCount: widget.total,
      );
      // 보상 연계 훅(1차 no-op). 멱등 커밋 안쪽이라 완주 1회당 1번만 불린다.
      await sl<QuizRewardHook>().onQuizCompleted(
        correctCount: widget.correct,
        total: widget.total,
        streak: streak,
      );
    }

    return _ResultVM(
      streak: streak,
      disclaimer: content.disclaimer,
      alreadyDone: alreadyDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuizTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Text('퀴즈 결과',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: FutureBuilder<_ResultVM>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final vm = snapshot.data;
          if (vm == null) {
            return Center(
              child: Text('결과를 불러오지 못했어요.',
                  style: TextStyle(fontSize: 14.sp)),
            );
          }
          return _buildResult(vm);
        },
      ),
    );
  }

  Widget _buildResult(_ResultVM vm) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 16.h),
              child: Column(
                children: [
                  SizedBox(height: 8.h),
                  _scoreCard(vm),
                  SizedBox(height: 16.h),
                  _streakCard(vm.streak),
                  SizedBox(height: 24.h),
                  _disclaimer(vm.disclaimer),
                ],
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  /// "N / 4 정답" 점수 카드. 정답 수는 코랄 강조(빨강 아님).
  Widget _scoreCard(_ResultVM vm) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: QuizTheme.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: QuizTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            vm.alreadyDone ? '오늘 퀴즈를 이미 풀었어요' : '오늘의 퀴즈 완료!',
            style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: QuizTheme.textSecondary),
          ),
          SizedBox(height: 16.h),
          // 큰 점수: N(코랄) / total(네이비)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${widget.correct}',
                  style: TextStyle(
                      fontSize: 56.sp,
                      fontWeight: FontWeight.w800,
                      color: QuizTheme.coral),
                ),
                TextSpan(
                  text: ' / ${widget.total}',
                  style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      color: QuizTheme.navy),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text('${widget.total}문제 중 ${widget.correct}개 정답!',
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: QuizTheme.navy)),
        ],
      ),
    );
  }

  /// 스트릭(🔥 N일 연속) 카드.
  Widget _streakCard(int streak) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: QuizTheme.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: QuizTheme.navy.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔥', style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 8.w),
          Text(
            '$streak일 연속 달성!',
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: QuizTheme.navy),
          ),
        ],
      ),
    );
  }

  /// 면책 고지(결과 화면 하단 고정).
  Widget _disclaimer(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11.5.sp,
            height: 1.5,
            color: QuizTheme.textSecondary),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: QuizTheme.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52.h,
        child: ElevatedButton(
          onPressed: () {
            // 홈으로(결과는 pushReplacement 로 들어와 진행 화면이 스택에 없음).
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: QuizTheme.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r)),
          ),
          child: Text('홈으로',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _ResultVM {
  final int streak;
  final String disclaimer;
  final bool alreadyDone;
  const _ResultVM({
    required this.streak,
    required this.disclaimer,
    required this.alreadyDone,
  });
}
