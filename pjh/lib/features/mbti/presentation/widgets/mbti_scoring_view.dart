import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/mbti_theme.dart';
import '../../../../shared/themes/app_theme.dart';

/// 계산 연출(2~3초). 네이비·코랄 톤의 가벼운 로딩 애니메이션.
///
/// [minDuration] 동안 연출을 보장하고, 완료 후 [onComplete] 를 호출한다.
/// (실제 채점·저장은 BLoC 에서 병행 — 이 위젯은 연출 타이밍만 담당)
class MbtiScoringView extends StatefulWidget {
  final Duration minDuration;
  final VoidCallback onComplete;

  const MbtiScoringView({
    super.key,
    this.minDuration = const Duration(milliseconds: 2400),
    required this.onComplete,
  });

  @override
  State<MbtiScoringView> createState() => _MbtiScoringViewState();
}

class _MbtiScoringViewState extends State<MbtiScoringView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  static const _messages = [
    '응답을 모으고 있어요',
    '성향을 분석하고 있어요',
    '딱 맞는 유형을 찾는 중',
  ];
  int _msgIndex = 0;
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _msgTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
    });

    _timer = Timer(widget.minDuration, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MbtiTheme.bg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 96.w,
              height: 96.w,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 96.w,
                        height: 96.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          value: null,
                          color: MbtiTheme.navy.withValues(
                            alpha: 0.4 + 0.6 * _controller.value,
                          ),
                          backgroundColor:
                              MbtiTheme.navy.withValues(alpha: 0.08),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.9 + 0.1 * _controller.value,
                        child: Icon(Icons.pets, size: 34.sp, color: AppTheme.textMuted),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: 28.h),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _messages[_msgIndex],
                key: ValueKey(_msgIndex),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: MbtiTheme.textPrimary,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '잠시만 기다려 주세요',
              style: TextStyle(
                fontSize: 13.sp,
                color: MbtiTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
