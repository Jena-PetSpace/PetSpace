import 'package:flutter/material.dart';
import '../widgets/emotion_loading_widget.dart';
import '../../data/services/gemini_ai_service.dart';
import 'health_result_page.dart';

/// 건강분석 전용 로딩 페이지
/// Navigator.push로 열리며, 분석 완료 시 pushReplacement로 결과 페이지로 이동
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HealthResultPage(result: result)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(e.toString()); // 에러 메시지를 pop result로 전달
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.expand(
        child: EmotionLoadingWidget(message: 'AI가 건강을 분석 중입니다...'),
      ),
    );
  }
}
