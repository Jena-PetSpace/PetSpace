import 'dart:io';

import '../models/emotion_analysis_model.dart';
import '../services/gemini_ai_service.dart';

abstract class EmotionAIService {
  Future<EmotionScoresModel> analyzeEmotionFromImage(File imageFile);
}

class EmotionAIServiceImpl implements EmotionAIService {
  late final GeminiAIService _geminiService;

  EmotionAIServiceImpl() {
    _geminiService = GeminiAIService();
  }

  @override
  Future<EmotionScoresModel> analyzeEmotionFromImage(File imageFile) async {
    return await _geminiService.analyzeEmotionFromImage(imageFile);
  }
}