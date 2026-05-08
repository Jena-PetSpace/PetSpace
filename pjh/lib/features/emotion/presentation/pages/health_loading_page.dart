import 'package:flutter/material.dart';
import '../../data/models/health_analysis_model.dart';
import '../widgets/ai_analysis_loading_widget.dart';
import '../../data/services/gemini_ai_service.dart';

/// 풀스크린 건강분석 로딩 페이지.
///
/// 분석 완료 + 진행바 100% 도달 시점에 [Navigator.pop]으로 결과를 반환한다.
/// pop 결과 타입:
/// - [HealthAnalysisModel] : 분석 성공
/// - [String]              : 에러 메시지
/// - null                  : 사용자가 뒤로가기로 취소
class HealthLoadingPage extends StatefulWidget {
  final List<String> imagePaths;
  final String selectedArea;
  final String userId;
  final String? petId;
  final String? petName;
  final String? petType;
  final String? breed;
  final String? age;
  final String? gender;
  final String? additionalContext;

  const HealthLoadingPage({
    super.key,
    required this.imagePaths,
    required this.selectedArea,
    required this.userId,
    this.petId,
    this.petName,
    this.petType,
    this.breed,
    this.age,
    this.gender,
    this.additionalContext,
  });

  @override
  State<HealthLoadingPage> createState() => _HealthLoadingPageState();
}

class _HealthLoadingPageState extends State<HealthLoadingPage> {
  bool _analysisDone = false;
  bool _popped = false;
  HealthAnalysisModel? _pendingResult;
  Object? _pendingError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final service = GeminiAIService();
      final result = await service.analyzeHealth(
        widget.imagePaths,
        area: widget.selectedArea,
        petName: widget.petName,
        petType: widget.petType,
        breed: widget.breed,
        age: widget.age,
        gender: widget.gender,
        additionalContext: widget.additionalContext,
        userId: widget.userId,
        petId: widget.petId,
      );
      if (!mounted) return;
      setState(() {
        _pendingResult = result;
        _analysisDone = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingError = e;
        _analysisDone = true;
      });
    }
  }

  void _handleProgressComplete() {
    if (!mounted || _popped) return;
    _popped = true;
    if (_pendingResult != null) {
      Navigator.of(context).pop(_pendingResult);
    } else if (_pendingError != null) {
      Navigator.of(context).pop(_pendingError.toString());
    }
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
