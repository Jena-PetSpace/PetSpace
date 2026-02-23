import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/api_config.dart';
import '../../../../core/error/exceptions.dart';
import '../models/emotion_analysis_model.dart';
import '../services/gemini_ai_service.dart';

abstract class EmotionAIService {
  Future<EmotionScoresModel> analyzeEmotionFromImage(File imageFile);
}

class EmotionAIServiceImpl implements EmotionAIService {
  late final GeminiAIService _geminiService;
  final SupabaseClient _supabase = Supabase.instance.client;

  EmotionAIServiceImpl() {
    _geminiService = GeminiAIService();
  }

  @override
  Future<EmotionScoresModel> analyzeEmotionFromImage(File imageFile) async {
    try {
      // Supabase Edge Function을 우선적으로 사용
      if (_supabase.auth.currentUser != null) {
        dev.log('🔵 [1차 시도] Supabase Edge Function으로 감정 분석 시작', name: 'EmotionAIService');
        return await _analyzeWithSupabaseEdgeFunction(imageFile);
      }

      // Gemini API 사용 가능한 경우 실제 AI 분석 수행
      if (ApiConfig.isGeminiConfigured) {
        dev.log('🟢 [2차 시도] Google Gemini API로 감정 분석 시작', name: 'EmotionAIService');
        dev.log('   API 엔드포인트: https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent', name: 'EmotionAIService');
        return await _geminiService.analyzeEmotionFromImage(imageFile);
      }

      // 최후 수단으로 데모 모드
      dev.log('🟡 [3차 시도] 데모 모드로 감정 분석 (랜덤 결과 생성)', name: 'EmotionAIService');
      return await _fallbackAnalysis(imageFile);

    } catch (e) {
      if (e is ImageException || e is AnalysisException) {
        rethrow;
      }

      // 오류 시 데모 모드로 fallback
      dev.log('🔴 AI 분석 오류, 데모 모드로 전환: ${e.toString()}', name: 'EmotionAIService.fallback');
      return await _fallbackAnalysis(imageFile);
    }
  }

  Future<EmotionScoresModel> _analyzeWithSupabaseEdgeFunction(File imageFile) async {
    try {
      // 이미지를 base64로 변환
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final user = _supabase.auth.currentUser!;

      // Supabase Edge Function 호출
      final response = await _supabase.functions.invoke(
        'analyze-emotion',
        body: {
          'imageBase64': base64Image,
          'userId': user.id,
        },
      );

      if (response.data['success'] == true) {
        final emotionData = response.data['data']['emotion_analysis'];
        return EmotionScoresModel.fromMap(emotionData);
      } else {
        throw AnalysisException(response.data['error'] ?? 'Edge Function 호출 실패');
      }
    } catch (e) {
      dev.log('Supabase Edge Function 오류: $e', name: 'EmotionAIService.edgeFunction');
      rethrow;
    }
  }

  Future<EmotionScoresModel> _fallbackAnalysis(File imageFile) async {
    // 이미지 파일 존재 여부 확인
    if (!await imageFile.exists()) {
      throw const ImageException('이미지 파일을 찾을 수 없습니다.');
    }

    // 파일 크기 확인 (5MB 제한)
    final fileSize = await imageFile.length();
    if (fileSize > 5 * 1024 * 1024) {
      throw const ImageException('이미지 파일이 너무 큽니다. (최대 5MB)');
    }

    // AI 분석 시뮬레이션 (2-3초 대기)
    await Future.delayed(const Duration(seconds: 2));

    // 데모용 랜덤 감정 점수 생성
    final random = Random();

    // 합이 1.0이 되도록 랜덤 감정 점수 생성
    final values = List.generate(5, (index) => random.nextDouble());
    final sum = values.reduce((a, b) => a + b);
    final normalizedValues = values.map((v) => v / sum).toList();

    return EmotionScoresModel(
      happiness: normalizedValues[0],
      sadness: normalizedValues[1],
      anxiety: normalizedValues[2],
      sleepiness: normalizedValues[3],
      curiosity: normalizedValues[4],
    );
  }

}