import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../data/datasources/quiz_local_data_source.dart';
import '../../domain/entities/quiz_content.dart';
import '../../domain/entities/quiz_result_snapshot.dart';
import '../../domain/entities/quiz_set.dart';
import '../../domain/services/quiz_session_builder.dart';
import '../theme/quiz_theme.dart';
import '../widgets/quiz_feedback_banner.dart';
import '../widgets/quiz_ox_button.dart';

/// O/X 퀴즈 진행 화면.
///
/// 흐름: 진술문 → O/X 한 번 선택(잠금, 번복 불가) → 즉시 정오 + 한 줄 해설 →
/// 사용자가 [다음] 탭으로 진행(자동 이동 금지, 해설 읽을 시간 보장).
///
/// **중간 이탈 = 커서 비전진:** 이 화면은 답을 메모리에만 모은다. 마지막 [다음]
/// 에서 결과 화면으로 정답 수를 넘기고, 실제 커밋(커서 전진·done·스트릭)은
/// 결과 화면(작업 3)에서 1회 수행한다. 그래서 4문제 다 안 풀고 뒤로가기/종료하면
/// 아무것도 기록되지 않아 재진입 시 같은 세트를 처음부터 다시 푼다(작업 1 원자성).
class QuizPlayPage extends StatefulWidget {
  const QuizPlayPage({super.key});

  @override
  State<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends State<QuizPlayPage> {
  late final Future<_PlayVM> _future;

  /// 문항별 사용자의 선택('O'/'X'). 길이는 세트 크기.
  final List<String?> _selected = [];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PlayVM> _load() async {
    final builder = sl<QuizSessionBuilder>();
    final content = await builder.contentDataSource.loadContent();
    final set = await builder.buildTodaySet();
    _selected
      ..clear()
      ..addAll(List<String?>.filled(set.length, null));
    return _PlayVM(content: content, set: set);
  }

  bool _isLockedAt(int i) => _selected.length > i && _selected[i] != null;

  int _correctCount(QuizSet set) {
    var c = 0;
    for (var i = 0; i < set.questions.length; i++) {
      final picked = _selected[i];
      if (picked != null && picked == set.questions[i].answer) c++;
    }
    return c;
  }

  void _select(QuizSet set, String value) {
    if (_isLockedAt(_index)) return; // 번복 불가
    setState(() => _selected[_index] = value);
  }

  Future<void> _next(_PlayVM vm) async {
    final isLast = _index >= vm.set.length - 1;
    if (isLast) {
      await _goResult(vm);
    } else {
      setState(() => _index += 1);
    }
  }

  /// 마지막 [다음]: 결과 복기 스냅샷을 저장하고 결과 화면으로 이동.
  ///
  /// 정답 수는 저장하지 않는다는 원칙은 유지하되, "오늘 1건 복기"를 위해
  /// 스냅샷(quiz_today_result_<오늘>)만 남긴다(누적 전적 아님 — 오늘 키만 보존).
  /// 커밋(커서·done·스트릭)은 결과 화면이 멱등으로 1회 수행.
  Future<void> _goResult(_PlayVM vm) async {
    final dateKey = quizDateKey();
    final answers = <QuizAnswerSnapshot>[];
    for (var i = 0; i < vm.set.questions.length; i++) {
      final q = vm.set.questions[i];
      answers.add(QuizAnswerSnapshot(
        qId: q.id,
        statement: q.statement,
        chosen: _selected[i] ?? '',
        answer: q.answer,
        explain: q.explain,
      ));
    }
    final snapshot = QuizResultSnapshot(
      dateKey: dateKey,
      correctCount: _correctCount(vm.set),
      total: vm.set.length,
      answers: answers,
    );
    await sl<QuizLocalDataSource>().saveResultSnapshot(snapshot);

    if (!mounted) return;
    // 결과 화면은 스냅샷에서 점수·복기를 읽는다(querystring 으로 dateKey 만).
    context.pushReplacement('/quiz/result?dateKey=$dateKey');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QuizTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('오늘의 퀴즈',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: FutureBuilder<_PlayVM>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Text('퀴즈를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.sp)),
              ),
            );
          }
          final vm = snapshot.data!;
          if (vm.set.isEmpty) {
            return Center(
              child: Text('출제할 문항이 없어요.',
                  style: TextStyle(fontSize: 14.sp)),
            );
          }
          return _buildQuiz(vm);
        },
      ),
    );
  }

  Widget _buildQuiz(_PlayVM vm) {
    final q = vm.set.questions[_index];
    final locked = _isLockedAt(_index);
    final picked = _selected[_index];
    final isCorrect = picked != null && picked == q.answer;

    return SafeArea(
      child: Column(
        children: [
          _progressBar(vm),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tagRow(vm.content, q),
                  SizedBox(height: 20.h),
                  _statement(q.statement),
                  SizedBox(height: 28.h),
                  Row(
                    children: [
                      QuizOxButton(
                        value: 'O',
                        locked: locked,
                        isSelected: picked == 'O',
                        isCorrectAnswer: q.answer == 'O',
                        onTap: () => _select(vm.set, 'O'),
                      ),
                      SizedBox(width: 14.w),
                      QuizOxButton(
                        value: 'X',
                        locked: locked,
                        isSelected: picked == 'X',
                        isCorrectAnswer: q.answer == 'X',
                        onTap: () => _select(vm.set, 'X'),
                      ),
                    ],
                  ),
                  if (locked) ...[
                    SizedBox(height: 20.h),
                    QuizFeedbackBanner(isCorrect: isCorrect, explain: q.explain),
                  ],
                ],
              ),
            ),
          ),
          _bottomBar(vm, locked),
        ],
      ),
    );
  }

  /// 상단 진행 표시(n/4 + 채워지는 막대).
  Widget _progressBar(_PlayVM vm) {
    final total = vm.set.length;
    final current = _index + 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('진행',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: QuizTheme.textSecondary)),
              Text('$current / $total',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: QuizTheme.navy)),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(100.r),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 8.h,
              backgroundColor: QuizTheme.navy.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation(QuizTheme.navy),
            ),
          ),
        ],
      ),
    );
  }

  /// 카테고리 칩 + 종 태그.
  Widget _tagRow(QuizContent content, QuizQuestion q) {
    return Row(
      children: [
        _chip(content.labelOfCategory(q.category)),
        SizedBox(width: 8.w),
        _speciesTag(q.species),
      ],
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: QuizTheme.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: QuizTheme.navy.withValues(alpha: 0.15)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: QuizTheme.navy)),
    );
  }

  Widget _speciesTag(String species) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: QuizTheme.bg,
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: QuizTheme.divider),
      ),
      child: Text(
        '${QuizTheme.speciesEmoji(species)} ${QuizTheme.speciesLabel(species)}',
        style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: QuizTheme.textSecondary),
      ),
    );
  }

  Widget _statement(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: QuizTheme.surface,
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
      child: Text(
        text,
        style: TextStyle(
            fontSize: 17.sp,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: QuizTheme.textPrimary),
      ),
    );
  }

  /// 하단 [다음]/[결과 보기] 버튼. 답을 골라야(잠금) 활성화 — 자동 이동 금지.
  Widget _bottomBar(_PlayVM vm, bool locked) {
    final isLast = _index >= vm.set.length - 1;
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
          onPressed: locked ? () => _next(vm) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: QuizTheme.navy,
            disabledBackgroundColor: QuizTheme.navy.withValues(alpha: 0.25),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r)),
          ),
          child: Text(
            locked ? (isLast ? '결과 보기' : '다음') : 'O 또는 X를 선택하세요',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _PlayVM {
  final QuizContent content;
  final QuizSet set;
  const _PlayVM({required this.content, required this.set});
}
