import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../data/datasources/quiz_content_data_source.dart';
import '../../data/datasources/quiz_local_data_source.dart';
import '../../domain/entities/quiz_result_snapshot.dart';
import '../../domain/services/quiz_reward_hook.dart';
import '../../domain/services/quiz_session_builder.dart';
import '../theme/quiz_theme.dart';
import '../widgets/quiz_review_tile.dart';

/// O/X 퀴즈 결과 + 복기 화면.
///
/// 두 진입 모두 `quiz_today_result_<오늘>` 스냅샷에서 점수·복기를 읽는다(재계산 없음):
/// - 진행 화면 마지막 [다음] → 스냅샷 저장 후 pushReplacement 로 진입(신규 완주).
/// - 홈 완료 카드 탭 → 같은 라우트로 진입(복기).
///
/// **로컬 커밋(커서·done·스트릭)은 신규 완주 1회만**, 멱등(이미 done 이면 스킵).
/// 상단 N/total + 🔥 스트릭, 하단 4문제 전부 복기(진술문·내 답·정답·해설·정오).
class QuizResultPage extends StatefulWidget {
  final String dateKey; // 'YYYYMMDD' (로컬)

  const QuizResultPage({super.key, required this.dateKey});

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

  /// 스냅샷 로드 + (신규 완주면) 멱등 커밋 + 훅 + 면책 로드.
  Future<_ResultVM> _commitAndLoad() async {
    final local = sl<QuizLocalDataSource>();
    final builder = sl<QuizSessionBuilder>();
    final content = await sl<QuizContentDataSource>().loadContent();

    final snapshot = await local.getResultSnapshot(widget.dateKey);
    final alreadyDone = await local.isDoneToday(widget.dateKey);

    int streak;
    if (alreadyDone) {
      // 재진입/복기: 커서·done·스트릭 불변. 현재 스트릭만.
      streak = await local.getStreak();
    } else {
      // 신규 완주: 원자적 커밋(커서 전진·완주 시 재셔플+0·done·스트릭).
      final total = snapshot?.total ?? 0;
      streak = await builder.commitCompletion(
        dateKey: widget.dateKey,
        solvedCount: total,
      );
      await sl<QuizRewardHook>().onQuizCompleted(
        correctCount: snapshot?.correctCount ?? 0,
        total: total,
        streak: streak,
      );
    }

    return _ResultVM(
      snapshot: snapshot,
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
          if (vm == null || vm.snapshot == null) {
            return _errorBody();
          }
          return _buildResult(vm);
        },
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('결과를 불러오지 못했어요.',
                style: TextStyle(fontSize: 14.sp), textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('홈으로'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(_ResultVM vm) {
    final snap = vm.snapshot!;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _scoreCard(vm, snap),
                  SizedBox(height: 16.h),
                  _streakCard(vm.streak),
                  SizedBox(height: 24.h),
                  _reviewHeader(),
                  SizedBox(height: 12.h),
                  ...List.generate(snap.answers.length, (i) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: QuizReviewTile(
                          index: i + 1, answer: snap.answers[i]),
                    );
                  }),
                  SizedBox(height: 12.h),
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

  /// "N / total 정답" 점수 카드. 정답 수는 코랄 강조(빨강 아님).
  Widget _scoreCard(_ResultVM vm, QuizResultSnapshot snap) {
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
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${snap.correctCount}',
                  style: TextStyle(
                      fontSize: 56.sp,
                      fontWeight: FontWeight.w800,
                      color: QuizTheme.coral),
                ),
                TextSpan(
                  text: ' / ${snap.total}',
                  style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      color: QuizTheme.navy),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text('${snap.total}문제 중 ${snap.correctCount}개 정답!',
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: QuizTheme.navy)),
        ],
      ),
    );
  }

  /// 스트릭(🔥 N일 연속) 카드. 스트릭 0(이상 데이터)이면 시작 안내.
  Widget _streakCard(int streak) {
    final hasStreak = streak > 0;
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
          Text(hasStreak ? '🔥' : '✨', style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 8.w),
          Text(
            hasStreak ? '$streak일 연속 달성!' : '오늘부터 시작!',
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: QuizTheme.navy),
          ),
        ],
      ),
    );
  }

  Widget _reviewHeader() {
    return Text('문제 다시 보기',
        style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: QuizTheme.textPrimary));
  }

  /// 면책 고지(결과 화면 하단 고정).
  Widget _disclaimer(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11.5.sp, height: 1.5, color: QuizTheme.textSecondary),
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
  final QuizResultSnapshot? snapshot;
  final int streak;
  final String disclaimer;
  final bool alreadyDone;
  const _ResultVM({
    required this.snapshot,
    required this.streak,
    required this.disclaimer,
    required this.alreadyDone,
  });
}
