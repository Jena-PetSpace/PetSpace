import 'dart:io';

import '../models/emotion_analysis_model.dart';
import '../services/gemini_ai_service.dart';

abstract class EmotionAIService {
  Future<EmotionScoresModel> analyzeEmotionFromImage(
    File imageFile, {
    String? petType,
    String? breed,
  });
  Future<EmotionScoresModel> analyzeEmotionFromImages(
    List<File> imageFiles, {
    String? petType,
    String? breed,
  });
}

class EmotionAIServiceImpl implements EmotionAIService {
  late final GeminiAIService _geminiService;

  EmotionAIServiceImpl() {
    _geminiService = GeminiAIService();
  }

  @override
  Future<EmotionScoresModel> analyzeEmotionFromImage(
    File imageFile, {
    String? petType,
    String? breed,
  }) async {
    return await _geminiService.analyzeEmotionFromImage(
      imageFile,
      petType: petType,
      breed: breed,
    );
  }

  @override
  Future<EmotionScoresModel> analyzeEmotionFromImages(
    List<File> imageFiles, {
    String? petType,
    String? breed,
  }) async {
    return await _geminiService.analyzeEmotionFromImages(
      imageFiles,
      petType: petType,
      breed: breed,
    );
  }
}
