import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../config/api_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../models/emotion_analysis_model.dart';

class GeminiAIService {
  final Dio _dio;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String _buildPrompt({String? petType, String? breed}) {
    final breedContext = (breed != null && breed.isNotEmpty)
        ? '\n[참고] 분석 대상: ${petType ?? '반려동물'}($breed). 이 품종의 특성을 고려해 해석해주세요.'
        : '';

    return """
이 사진의 동물(강아지 또는 고양이)을 종합 분석해주세요.
$breedContext

[1] 감정 분포 (0.0~1.0, 합계 = 1.0):
- happiness: 행복함 (꼬리 흔들기, 입 벌림, 편안한 표정)
- sadness: 슬픔 (귀 처짐, 눈 처짐, 우울한 표정)
- anxiety: 불안 (경계, 긴장된 자세, 스트레스)
- sleepiness: 졸림 (눈 감김, 휴식 자세, 나른함)
- curiosity: 호기심 (귀 세움, 집중, 탐색 자세)

[2] 추가 분석 지표 (각각 0~100 정수):
- stress_level: 스트레스 지수
- activity_level: 활동량 예측
- comfort_level: 편안함/사회성

[3] 건강 신호 (문자열):
- health_signal: "good" / "normal" / "caution"

[4] 부위별 분석 (한국어):
- eyes: 눈 상태와 감지된 감정 신호
- ears: 귀 상태와 감지된 감정 신호
- mouth: 입 상태와 감지된 감정 신호
- posture: 자세 상태와 감지된 감정 신호

[5] 건강 관련 팁:
- 현재 감정/스트레스 상태에서 보호자가 체크해야 할 항목 2~3가지 (짧은 한국어 문장)

${(breed != null && breed.isNotEmpty) ? '[6] 품종 해석:\n- 해당 품종의 특성을 고려한 감정 해석 1~2문장\n' : ''}
반드시 아래 JSON 형식으로만 응답하세요:
{
  "happiness": 0.3,
  "sadness": 0.1,
  "anxiety": 0.2,
  "sleepiness": 0.1,
  "curiosity": 0.3,
  "stress_level": 35,
  "activity_level": 60,
  "health_signal": "good",
  "comfort_level": 75,
  "facial_features": {
    "eyes": {"state": "초롱초롱한 눈", "signal": "호기심"},
    "ears": {"state": "앞으로 세움", "signal": "집중"},
    "mouth": {"state": "살짝 벌림", "signal": "이완"},
    "posture": {"state": "앉아 있음", "signal": "안정"}
  },
  "health_tips": ["식욕 변화가 없는지 확인하세요", "산책 후 발바닥 상태를 체크하세요"]${(breed != null && breed.isNotEmpty) ? ',\n  "breed_insight": "이 품종은..."' : ''}
}

동물이 보이지 않으면 감정은 각각 0.2, 추가 지표는 50, health_signal은 "normal", facial_features의 state/signal은 "확인 불가"로 응답하세요.
""";
  }

  GeminiAIService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 120);
  }

  Future<EmotionScoresModel> analyzeEmotionFromImage(
    File imageFile, {
    String? petType,
    String? breed,
  }) async {
    if (!ApiConfig.isGeminiConfigured) {
      throw const AnalysisException('Gemini API가 설정되지 않았습니다.');
    }

    try {
      log('Gemini API 호출 시작', name: 'GeminiAI');

      if (!await imageFile.exists()) {
        throw const ImageException('이미지 파일을 찾을 수 없습니다.');
      }

      final fileSize = await imageFile.length();
      if (fileSize > 20 * 1024 * 1024) {
        throw const ImageException('이미지 파일이 너무 큽니다. (최대 20MB)');
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _getMimeType(imageFile.path);
      final prompt = _buildPrompt(petType: petType, breed: breed);

      final requestData = _buildRequest([
        {"text": prompt},
        {"inline_data": {"mime_type": mimeType, "data": base64Image}},
      ]);

      final response = await _callApi(requestData);
      return _parseResponse(response);

    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      if (e is ImageException || e is AnalysisException) rethrow;
      throw AnalysisException('감정 분석 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  Future<EmotionScoresModel> analyzeEmotionFromImages(
    List<File> imageFiles, {
    String? petType,
    String? breed,
  }) async {
    if (!ApiConfig.isGeminiConfigured) {
      throw const AnalysisException('Gemini API가 설정되지 않았습니다.');
    }
    if (imageFiles.isEmpty) {
      throw const AnalysisException('분석할 이미지가 없습니다.');
    }
    if (imageFiles.length == 1) {
      return analyzeEmotionFromImage(imageFiles.first, petType: petType, breed: breed);
    }

    try {
      log('다중 이미지 분석 시작 (${imageFiles.length}장)', name: 'GeminiAI');

      final parts = <Map<String, dynamic>>[];
      final prompt = _buildPrompt(petType: petType, breed: breed);

      parts.add({
        "text": "아래 ${imageFiles.length}장의 사진은 모두 같은 반려동물입니다. 모든 사진을 종합적으로 분석해주세요.\n\n$prompt",
      });

      for (final imageFile in imageFiles) {
        if (!await imageFile.exists()) continue;
        final fileSize = await imageFile.length();
        if (fileSize > 20 * 1024 * 1024) continue;

        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        final mimeType = _getMimeType(imageFile.path);

        parts.add({
          "inline_data": {"mime_type": mimeType, "data": base64Image}
        });
        log('이미지 추가: ${(fileSize / 1024).toStringAsFixed(1)} KB', name: 'GeminiAI');
      }

      if (parts.length < 2) {
        throw const AnalysisException('유효한 이미지가 없습니다.');
      }

      final requestData = _buildRequest(parts);
      final response = await _callApi(requestData);
      return _parseResponse(response);

    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      if (e is AnalysisException) rethrow;
      throw AnalysisException('감정 분석 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  // B-4: 텍스트 전용 Gemini 호출 (이미지 없이, JSON 강제 아님)
  Future<String?> generateText(String prompt) async {
    if (!ApiConfig.isGeminiConfigured) return null;

    try {
      final requestData = _buildTextRequest([
        {"text": prompt},
      ]);
      final response = await _callApi(requestData);
      final textContent = response['candidates'][0]['content']['parts'][0]['text'] as String;
      return textContent.trim();
    } catch (e) {
      log('generateText 오류: $e', name: 'GeminiAI');
      return null;
    }
  }

  // ── 내부 헬퍼 ──

  String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      default:     return 'image/jpeg';
    }
  }

  Map<String, dynamic> _buildRequest(List<Map<String, dynamic>> parts) {
    return {
      "contents": [{"parts": parts}],
      "generationConfig": {
        "temperature": 0.4,
        "topK": 32,
        "topP": 1,
        "maxOutputTokens": 4096,
        "responseMimeType": "application/json",
      },
      "safetySettings": [
        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
        {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
        {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
      ],
    };
  }

  // 텍스트 전용 (JSON 강제 없음)
  Map<String, dynamic> _buildTextRequest(List<Map<String, dynamic>> parts) {
    return {
      "contents": [{"parts": parts}],
      "generationConfig": {
        "temperature": 0.7,
        "topK": 40,
        "topP": 0.95,
        "maxOutputTokens": 2048,
      },
      "safetySettings": [
        {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
        {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
        {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
        {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_MEDIUM_AND_ABOVE"},
      ],
    };
  }

  Future<Map<String, dynamic>> _callApi(Map<String, dynamic> requestData) async {
    final response = await _dio.post(
      '$_baseUrl?key=${ApiConfig.geminiApiKey}',
      data: requestData,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.statusCode != 200) {
      throw AnalysisException('Gemini API 호출 실패: ${response.statusCode}');
    }

    final data = response.data;
    if (data['candidates'] == null ||
        data['candidates'].isEmpty ||
        data['candidates'][0]['content'] == null ||
        data['candidates'][0]['content']['parts'] == null ||
        data['candidates'][0]['content']['parts'].isEmpty) {
      throw const AnalysisException('Gemini API 응답이 비어있습니다.');
    }

    return data;
  }

  // 중첩 JSON 지원 파서 (마크다운 코드블록, thinking 태그 등 제거 후 추출)
  String? _extractJson(String text) {
    // 1) ```json ... ``` 코드블록에서 추출 시도
    final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)```');
    final codeBlockMatch = codeBlockRegex.firstMatch(text);
    final cleanText = codeBlockMatch != null ? codeBlockMatch.group(1)! : text;

    // 2) 중첩 브레이스 기반 파서
    int start = cleanText.indexOf('{');
    if (start == -1) return null;
    int depth = 0;
    bool inString = false;
    bool escaped = false;
    for (int i = start; i < cleanText.length; i++) {
      final c = cleanText[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (c == '\\') {
        escaped = true;
        continue;
      }
      if (c == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (c == '{') depth++;
      if (c == '}') depth--;
      if (depth == 0) return cleanText.substring(start, i + 1);
    }
    return null;
  }

  EmotionScoresModel _parseResponse(Map<String, dynamic> responseData) {
    final textContent = responseData['candidates'][0]['content']['parts'][0]['text'] as String;
    log('응답 텍스트: $textContent', name: 'GeminiAI');

    final jsonStr = _extractJson(textContent);
    if (jsonStr == null) {
      throw const AnalysisException('응답에서 JSON을 찾을 수 없습니다.');
    }

    final emotionData = jsonDecode(jsonStr) as Map<String, dynamic>;

    // 감정 점수 (합계 1.0 정규화)
    double happiness  = _parseDouble(emotionData['happiness'],  0.2);
    double sadness    = _parseDouble(emotionData['sadness'],    0.2);
    double anxiety    = _parseDouble(emotionData['anxiety'],    0.2);
    double sleepiness = _parseDouble(emotionData['sleepiness'], 0.2);
    double curiosity  = _parseDouble(emotionData['curiosity'],  0.2);

    final total = happiness + sadness + anxiety + sleepiness + curiosity;
    if (total > 0) {
      happiness  /= total;
      sadness    /= total;
      anxiety    /= total;
      sleepiness /= total;
      curiosity  /= total;
    }

    // 추가 지표
    final stressLevel  = _parseInt(emotionData['stress_level'],  50);
    final activityLevel = _parseInt(emotionData['activity_level'], 50);
    final comfortLevel  = _parseInt(emotionData['comfort_level'],  50);
    final healthSignal  = emotionData['health_signal'] as String? ?? 'normal';

    // A-1: 부위별 분석
    Map<String, FacialFeature>? facialFeatures;
    final rawFeatures = emotionData['facial_features'];
    if (rawFeatures is Map<String, dynamic>) {
      facialFeatures = {};
      for (final entry in rawFeatures.entries) {
        if (entry.value is Map<String, dynamic>) {
          facialFeatures[entry.key] = FacialFeature.fromJson(entry.value);
        }
      }
      if (facialFeatures.isEmpty) facialFeatures = null;
    }

    // A-3: 건강 팁
    final rawTips = emotionData['health_tips'];
    final healthTips = rawTips is List
        ? List<String>.from(rawTips)
        : <String>[];

    // A-6: 품종 해석
    final breedInsight = emotionData['breed_insight'] as String?;

    log('분석 완료 - happiness: ${happiness.toStringAsFixed(2)}, stress: $stressLevel', name: 'GeminiAI');

    return EmotionScoresModel(
      happiness: happiness,
      sadness: sadness,
      anxiety: anxiety,
      sleepiness: sleepiness,
      curiosity: curiosity,
      stressLevel: stressLevel,
      activityLevel: activityLevel,
      healthSignal: healthSignal,
      comfortLevel: comfortLevel,
      facialFeatures: facialFeatures,
      healthTips: healthTips,
      breedInsight: breedInsight,
    );
  }

  AnalysisException _handleDioException(DioException e) {
    log('DioException: ${e.type} - ${e.message}', name: 'GeminiAI');
    log('Response: ${e.response?.data}', name: 'GeminiAI');
    if (e.response?.statusCode == 400) {
      return const AnalysisException('잘못된 요청입니다. 이미지 형식을 확인해주세요.');
    } else if (e.response?.statusCode == 401) {
      return const AnalysisException('API 키가 유효하지 않습니다.');
    } else if (e.response?.statusCode == 429) {
      return const AnalysisException('API 사용량 한도를 초과했습니다.');
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return const AnalysisException('연결 시간이 초과되었습니다.');
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return const AnalysisException('응답 시간이 초과되었습니다.');
    }
    return AnalysisException('네트워크 오류가 발생했습니다: ${e.message}');
  }

  double _parseDouble(dynamic value, double defaultValue) {
    if (value is num) return value.toDouble().clamp(0.0, 1.0);
    if (value is String) {
      try { return double.parse(value).clamp(0.0, 1.0); } catch (_) {}
    }
    return defaultValue;
  }

  int _parseInt(dynamic value, int defaultValue) {
    if (value is num) return value.toInt().clamp(0, 100);
    if (value is String) {
      try { return int.parse(value).clamp(0, 100); } catch (_) {}
    }
    return defaultValue;
  }
}
