import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../pages/emotion_result_page.dart';
import '../widgets/emotion_loading_widget.dart';

/// ShellRoute 밖에 위치 → 하단 네비바 완전히 없음
/// EmotionAnalysisBloc stream을 구독해서 완료/에러 시 자동 전환
class EmotionLoadingPage extends StatefulWidget {
  /// 감정분석: imagePaths 전달 (결과 페이지에 필요)
  final List<String> imagePaths;

  /// 로딩 페이지 진입 후 dispatch할 이벤트 (race condition 방지)
  final EmotionAnalysisEvent? event;

  const EmotionLoadingPage({
    super.key,
    this.imagePaths = const [],
    this.event,
  });

  @override
  State<EmotionLoadingPage> createState() => _EmotionLoadingPageState();
}

class _EmotionLoadingPageState extends State<EmotionLoadingPage> {
  StreamSubscription? _sub;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<EmotionAnalysisBloc>();

      // stream 구독 먼저 등록
      _sub = bloc.stream.listen((state) {
        if (!mounted || _navigated) return;
        if (state is EmotionAnalysisSuccess) {
          _navigated = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: EmotionResultPage(
                  analysis: state.analysis,
                  imagePaths: List.from(widget.imagePaths),
                ),
              ),
            ),
          );
        } else if (state is EmotionAnalysisError) {
          _navigated = true;
          context.pop(); // 로딩 페이지 닫기
        }
      });

      // 구독 후 이벤트 발송 (race condition 방지)
      if (widget.event != null) {
        bloc.add(widget.event!);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.expand(child: EmotionLoadingWidget()),
    );
  }
}
