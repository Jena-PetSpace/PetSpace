import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/ai_analysis_loading_widget.dart';

/// 풀스크린 로딩 페이지 — rootNavigator로 push하면 ShellRoute 위에 떠 하단
/// 네비바를 가린다.
///
/// 분석 완료 + 진행바 100% 도달 시점에 [Navigator.pop]으로 결과를 반환한다.
/// 호출자(emotion_analysis_page)가 await로 받아 결과 페이지로 push한다.
///
/// pop 결과 타입:
/// - [EmotionAnalysisSuccess] : 분석 성공
/// - [EmotionAnalysisError]   : 분석 실패
/// - null                     : 사용자가 뒤로가기로 취소
class EmotionLoadingPage extends StatefulWidget {
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
  bool _popped = false;
  bool _analysisDone = false;
  EmotionAnalysisSuccess? _pendingSuccess;
  EmotionAnalysisError? _pendingError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<EmotionAnalysisBloc>();

      _sub = bloc.stream.listen((state) {
        if (!mounted || _popped) return;
        if (state is EmotionAnalysisSuccess) {
          setState(() {
            _pendingSuccess = state;
            _analysisDone = true;
          });
        } else if (state is EmotionAnalysisError) {
          setState(() {
            _pendingError = state;
            _analysisDone = true;
          });
        }
      });

      if (widget.event != null) {
        bloc.add(widget.event!);
      }
    });
  }

  void _handleProgressComplete() {
    if (!mounted || _popped) return;
    _popped = true;
    if (_pendingSuccess != null) {
      Navigator.of(context).pop(_pendingSuccess);
    } else if (_pendingError != null) {
      Navigator.of(context).pop(_pendingError);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: AiAnalysisLoadingWidget(
          analysisCompleted: _analysisDone,
          onProgressComplete: _handleProgressComplete,
        ),
      ),
    );
  }
}
