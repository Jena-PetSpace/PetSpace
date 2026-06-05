import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../data/datasources/quiz_local_data_source.dart';
import '../theme/quiz_theme.dart';

/// 홈 "오늘의 퀴즈" 카드. 오늘 완료 여부로 분기:
/// - 미완료(quiz_done_<오늘> 없음) → "오늘의 퀴즈 풀기" CTA → /quiz/play
/// - 완료 → "오늘 완료!" + 정답 수 + 스트릭 → /quiz/result(스냅샷 복기)
///
/// "오늘"은 로컬 자정 경계의 quizDateKey 로 판단 — 자정이 지나면 키가 달라져
/// 자동으로 미완료로 돌아간다(새 세트 가능과 일관). 운세 카드와 같은 톤·radius·여백.
class HomeQuizCard extends StatefulWidget {
  const HomeQuizCard({super.key});

  @override
  State<HomeQuizCard> createState() => _HomeQuizCardState();
}

class _HomeQuizCardState extends State<HomeQuizCard> {
  /// 이번 빌드의 오늘 날짜 키(로컬). 위젯 수명 동안 고정.
  final String _today = quizDateKey();

  bool _loaded = false;
  bool _done = false;
  int _streak = 0;
  int _correct = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = sl<QuizLocalDataSource>();
    // 과거 done·result 스냅샷 키 정리(오늘 키 보존). 실패해도 카드엔 영향 없음.
    try {
      await local.purgePastDoneKeys(_today);
    } catch (_) {}

    final done = await local.isDoneToday(_today);
    final streak = await local.getStreak();
    int correct = 0, total = 0;
    if (done) {
      final snap = await local.getResultSnapshot(_today);
      correct = snap?.correctCount ?? 0;
      total = snap?.total ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _done = done;
      _streak = streak;
      _correct = correct;
      _total = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 로드 전엔 빈 카드 자리(레이아웃 흔들림 최소화 — 운세 카드와 동일 외곽).
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: QuizTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: !_loaded
          ? _skeleton()
          : (_done ? _doneCard(context) : _ctaCard(context)),
    );
  }

  Widget _skeleton() => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(children: [
          Text('🧠', style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 12.w),
          Text('오늘의 퀴즈',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: QuizTheme.navy)),
        ]),
      );

  // ── 미완료: "오늘의 퀴즈 풀기" CTA ───────────────────────
  Widget _ctaCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => context.push('/quiz/play'),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Text('🧠', style: TextStyle(fontSize: 22.sp)),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('오늘의 O/X 퀴즈',
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: QuizTheme.navy)),
                      if (_streak > 0) ...[
                        SizedBox(width: 6.w),
                        _streakBadge(_streak),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text('하루 4문제, 풀고 스트릭 쌓기',
                      style: TextStyle(
                          fontSize: 11.sp, color: QuizTheme.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: QuizTheme.coral,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text('풀기',
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 완료: "오늘 완료!" + 정답 수 + 스트릭 → 복기 진입 ───────
  Widget _doneCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () => context.push('/quiz/result?dateKey=$_today'),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: QuizTheme.correct.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle,
                  size: 26.sp, color: QuizTheme.correct),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('오늘 퀴즈 완료!',
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: QuizTheme.navy)),
                      if (_streak > 0) ...[
                        SizedBox(width: 6.w),
                        _streakBadge(_streak),
                      ],
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    _total > 0 ? '$_total문제 중 $_correct개 정답 · 다시 보기' : '결과 다시 보기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: QuizTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 22.w, color: QuizTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  /// 🔥 N일 배지(스트릭 1 이상일 때만 노출 — 0/끊김은 호출부에서 숨김).
  Widget _streakBadge(int streak) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: QuizTheme.coral.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text('🔥 $streak일',
          style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
              color: QuizTheme.coral)),
    );
  }
}
