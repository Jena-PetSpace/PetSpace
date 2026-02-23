import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../config/api_config.dart';
import '../../../../core/error/exceptions.dart';
import '../models/emotion_analysis_model.dart';

class GeminiAIService {
  final Dio _dio;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  GeminiAIService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
  }

  Future<EmotionScoresModel> analyzeEmotionFromImage(File imageFile) async {
    if (!ApiConfig.isGeminiConfigured) {
      throw const AnalysisException('Gemini API가 설정되지 않았습니다.');
    }

    try {
      log('✅ Gemini API 설정 확인 완료', name: 'GeminiAIService');
      log('📍 API Key: ${ApiConfig.geminiApiKey.substring(0, 10)}...', name: 'GeminiAIService');

      // 이미지 파일 존재 여부 확인
      if (!await imageFile.exists()) {
        throw const ImageException('이미지 파일을 찾을 수 없습니다.');
      }

      // 파일 크기 확인 (20MB 제한 - Gemini API 제한)
      final fileSize = await imageFile.length();
      if (fileSize > 20 * 1024 * 1024) {
        throw const ImageException('이미지 파일이 너무 큽니다. (최대 20MB)');
      }

      log('📦 이미지 파일 크기: ${(fileSize / 1024).toStringAsFixed(2)} KB', name: 'GeminiAIService');

      // 이미지를 base64로 인코딩
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      log('🔄 이미지 base64 인코딩 완료', name: 'GeminiAIService');

      // 이미지 MIME 타입 결정
      final extension = imageFile.path.toLowerCase().split('.').last;
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      // Gemini API 요청 페이로드
      final requestData = {
        "contents": [
          {
            "parts": [
              {
                "text": """
이 이미지의 동물(강아지 또는 고양이)의 감정을 분석해주세요.

다음 5가지 감정에 대해 0.0~1.0 사이의 점수를 부여해주세요 (모든 값의 합은 1.0이 되어야 합니다):

1. happiness (행복함): 꼬리를 흔들거나, 입을 벌리고 있거나, 편안한 표정
2. sadness (슬픔): 귀가 처져있거나, 눈이 처져있거나, 우울한 표정
3. anxiety (불안): 경계하는 모습이나, 긴장된 자세, 스트레스를 받는 모습
4. sleepiness (졸림): 눈이 감기거나, 휴식 자세, 나른한 모습
5. curiosity (호기심): 귀가 세워져 있거나, 집중하는 모습, 탐색하는 자세

응답은 반드시 다음 JSON 형식으로만 응답해주세요:
{
  "happiness": 0.3,
  "sadness": 0.1,
  "anxiety": 0.2,
  "sleepiness": 0.1,
  "curiosity": 0.3
}

동물이 보이지 않거나 명확하지 않은 경우에는 균등하게 분배해주세요 (각각 0.2).
"""
              },
              {
                "inline_data": {
                  "mime_type": mimeType,
                  "data": base64Image
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 1,
          "maxOutputTokens": 4096,
        },
        "safetySettings": [
          {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE"
          }
        ]
      };

      // API 호출
      log('🚀 Gemini API 호출 시작...', name: 'GeminiAIService');
      log('🌐 URL: $_baseUrl', name: 'GeminiAIService');

      final response = await _dio.post(
        '$_baseUrl?key=${ApiConfig.geminiApiKey}',
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      log('✅ Gemini API 응답 수신 완료: ${response.statusCode}', name: 'GeminiAIService');

      if (response.statusCode != 200) {
        throw AnalysisException('Gemini API 호출 실패: ${response.statusCode}');
      }

      // 응답 파싱
      final responseData = response.data;
      if (responseData['candidates'] == null ||
          responseData['candidates'].isEmpty ||
          responseData['candidates'][0]['content'] == null ||
          responseData['candidates'][0]['content']['parts'] == null ||
          responseData['candidates'][0]['content']['parts'].isEmpty) {
        throw const AnalysisException('Gemini API 응답이 비어있습니다.');
      }

      final textContent = responseData['candidates'][0]['content']['parts'][0]['text'] as String;

      // JSON 응답에서 감정 점수 추출
      try {
        // JSON 부분만 추출하기 위해 정규식 사용
        final jsonMatch = RegExp(r'\{[^}]*\}').firstMatch(textContent);
        if (jsonMatch == null) {
          throw const AnalysisException('응답에서 JSON을 찾을 수 없습니다.');
        }

        final jsonString = jsonMatch.group(0)!;
        final emotionData = jsonDecode(jsonString) as Map<String, dynamic>;

        // 감정 점수 추출 및 검증
        double happiness = _parseDouble(emotionData['happiness'], 0.2);
        double sadness = _parseDouble(emotionData['sadness'], 0.2);
        double anxiety = _parseDouble(emotionData['anxiety'], 0.2);
        double sleepiness = _parseDouble(emotionData['sleepiness'], 0.2);
        double curiosity = _parseDouble(emotionData['curiosity'], 0.2);

        // 합계 검증 및 정규화
        final total = happiness + sadness + anxiety + sleepiness + curiosity;
        if (total > 0) {
          happiness /= total;
          sadness /= total;
          anxiety /= total;
          sleepiness /= total;
          curiosity /= total;
        }

        return EmotionScoresModel(
          happiness: happiness,
          sadness: sadness,
          anxiety: anxiety,
          sleepiness: sleepiness,
          curiosity: curiosity,
        );

      } catch (e) {
        log('JSON 파싱 오류: $e', name: 'GeminiAIService.parse');
        log('원본 응답: $textContent', name: 'GeminiAIService.response');

        // 파싱에 실패한 경우 기본값 반환
        return const EmotionScoresModel(
          happiness: 0.2,
          sadness: 0.2,
          anxiety: 0.2,
          sleepiness: 0.2,
          curiosity: 0.2,
        );
      }

    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw const AnalysisException('잘못된 요청입니다. 이미지 형식을 확인해주세요.');
      } else if (e.response?.statusCode == 401) {
        throw const AnalysisException('API 키가 유효하지 않습니다.');
      } else if (e.response?.statusCode == 429) {
        throw const AnalysisException('API 사용량 한도를 초과했습니다.');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw const AnalysisException('연결 시간이 초과되었습니다.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw const AnalysisException('응답 시간이 초과되었습니다.');
      } else {
        throw AnalysisException('네트워크 오류가 발생했습니다: ${e.message}');
      }
    } catch (e) {
      if (e is ImageException || e is AnalysisException) {
        rethrow;
      }
      throw AnalysisException('감정 분석 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  double _parseDouble(dynamic value, double defaultValue) {
    if (value is num) {
      return value.toDouble().clamp(0.0, 1.0);
    } else if (value is String) {
      try {
        return double.parse(value).clamp(0.0, 1.0);
      } catch (e) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
}