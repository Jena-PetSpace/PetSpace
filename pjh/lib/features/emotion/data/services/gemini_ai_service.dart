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
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String _buildPrompt({String? petType, String? breed}) {
    final breedContext = (breed != null && breed.isNotEmpty)
        ? '\n[참고] 분석 대상: ${petType ?? '반려동물'}($breed). 이 품종의 특성을 고려해 해석해주세요.'
        : '';

    return """
이 사진의 반려동물을 아래 심리학·신경과학 이론에 기반하여 분석해주세요.
$breedContext

[분석 이론 기반]
- Russell(1980) 원형 모델: valence(긍정/부정) × arousal(고각성/저각성)
- Panksepp(1998) 정동 신경과학: 포유류 7대 감정 시스템
- Ekman(1992) 기본 감정: 얼굴 근육 움직임 기반 분류

[1] 감정 분포 (0.0~1.0, 합계 반드시 1.0):
- happiness  (기쁨):  긍정-중간각성 | Panksepp PLAY    | 입 열림·눈 빛남·편안한 귀
- calm       (편안함): 긍정-저각성  | Panksepp CARE    | 눈 반쯤 감음·이완된 귀입자세
- excitement (흥분):  긍정-고각성  | Ekman 확장       | 귀 세움·눈 크게·입 열림
- curiosity  (호기심): 중립-중간각성 | Panksepp SEEKING | 귀 앞·고개 기울임
- anxiety    (불안):  부정-중간각성 | Panksepp ANXIETY | 귀 뒤·눈 흰자·긴장
- fear       (공포):  부정-고각성  | Panksepp FEAR    | 귀 완전뒤·동공확대·몸낮춤
- sadness    (슬픔):  부정-저각성  | Panksepp GRIEF   | 귀처짐·눈처짐·고개숙임
- discomfort (불편함): 부정-중간각성 | Panksepp RAGE전  | 눈살찌푸림·입긴장

[2] 생리 지표 (Russell 모델: 각성 상태, 감정과 별도):
- is_sleepy: 졸림 true/false
- stress_level: 0~100
- activity_level: 0~100
- comfort_level: 0~100

[3] 건강 신호: "good" / "normal" / "caution"
[4] 부위별 분석 (한국어): eyes, ears, mouth, posture (state + signal)
[5] 건강 관련 팁 2~3가지 (짧은 한국어 문장)
${breedContext.isNotEmpty ? '[6] 품종 해석 1~2문장\n' : ''}
반드시 아래 JSON 형식으로만 응답하세요:
{
  "happiness": 0.0, "calm": 0.0, "excitement": 0.0, "curiosity": 0.0,
  "anxiety": 0.0, "fear": 0.0, "sadness": 0.0, "discomfort": 0.0,
  "is_sleepy": false,
  "stress_level": 0, "activity_level": 0, "comfort_level": 0,
  "health_signal": "good",
  "facial_features": {
    "eyes": {"state": "", "signal": ""},
    "ears": {"state": "", "signal": ""},
    "mouth": {"state": "", "signal": ""},
    "posture": {"state": "", "signal": ""}
  },
  "health_tips": ["", ""]${breedContext.isNotEmpty ? ',\n  "breed_insight": ""' : ''}
}

동물이 보이지 않으면 감정 각각 0.125, is_sleepy false, 추가 지표 50, health_signal "normal"로 응답하세요.
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
        {
          "inline_data": {"mime_type": mimeType, "data": base64Image}
        },
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
      return analyzeEmotionFromImage(imageFiles.first,
          petType: petType, breed: breed);
    }

    try {
      log('다중 이미지 분석 시작 (${imageFiles.length}장)', name: 'GeminiAI');

      final parts = <Map<String, dynamic>>[];
      final prompt = _buildPrompt(petType: petType, breed: breed);

      parts.add({
        "text":
            "아래 ${imageFiles.length}장의 사진은 모두 같은 반려동물입니다. 모든 사진을 종합적으로 분석해주세요.\n\n$prompt",
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
        log('이미지 추가: ${(fileSize / 1024).toStringAsFixed(1)} KB',
            name: 'GeminiAI');
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
      final textContent =
          response['candidates'][0]['content']['parts'][0]['text'] as String;
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
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Map<String, dynamic> _buildRequest(List<Map<String, dynamic>> parts) {
    return {
      "contents": [
        {"parts": parts}
      ],
      "generationConfig": {
        "temperature": 0.4,
        "topK": 32,
        "topP": 1,
        "maxOutputTokens": 4096,
        "responseMimeType": "application/json",
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
        },
      ],
    };
  }

  // 텍스트 전용 (JSON 강제 없음)
  Map<String, dynamic> _buildTextRequest(List<Map<String, dynamic>> parts) {
    return {
      "contents": [
        {"parts": parts}
      ],
      "generationConfig": {
        "temperature": 0.7,
        "topK": 40,
        "topP": 0.95,
        "maxOutputTokens": 2048,
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
        },
      ],
    };
  }

  Future<Map<String, dynamic>> _callApi(
      Map<String, dynamic> requestData) async {
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
    final textContent =
        responseData['candidates'][0]['content']['parts'][0]['text'] as String;
    log('응답 텍스트: $textContent', name: 'GeminiAI');

    final jsonStr = _extractJson(textContent);
    if (jsonStr == null) {
      throw const AnalysisException('응답에서 JSON을 찾을 수 없습니다.');
    }

    final emotionData = jsonDecode(jsonStr) as Map<String, dynamic>;

    // 8감정 파싱 (sleepiness 제외)
    double happiness  = _parseDouble(emotionData['happiness'],  0.125);
    double calm       = _parseDouble(emotionData['calm'],       0.125);
    double excitement = _parseDouble(emotionData['excitement'], 0.125);
    double curiosity  = _parseDouble(emotionData['curiosity'],  0.125);
    double anxiety    = _parseDouble(emotionData['anxiety'],    0.125);
    double fear       = _parseDouble(emotionData['fear'],       0.125);
    double sadness    = _parseDouble(emotionData['sadness'],    0.125);
    double discomfort = _parseDouble(emotionData['discomfort'], 0.125);

    // 합계 1.0 정규화 (sleepiness 제외)
    final total = happiness + calm + excitement + curiosity +
                  anxiety + fear + sadness + discomfort;
    if (total > 0) {
      happiness  /= total;
      calm       /= total;
      excitement /= total;
      curiosity  /= total;
      anxiety    /= total;
      fear       /= total;
      sadness    /= total;
      discomfort /= total;
    }

    // 생리지표 파싱 (is_sleepy)
    final isSleepy = emotionData['is_sleepy'] as bool? ?? false;

    // 추가 지표
    final stressLevel   = _parseInt(emotionData['stress_level'],   50);
    final activityLevel = _parseInt(emotionData['activity_level'], 50);
    final comfortLevel  = _parseInt(emotionData['comfort_level'],  50);
    final healthSignal  = emotionData['health_signal'] as String? ?? 'normal';

    // 부위별 분석
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

    // 건강 팁
    final rawTips = emotionData['health_tips'];
    final healthTips =
        rawTips is List ? List<String>.from(rawTips) : <String>[];

    // 품종 해석
    final breedInsight = emotionData['breed_insight'] as String?;

    log('분석 완료 - happiness: ${happiness.toStringAsFixed(2)}, '
        'fear: ${fear.toStringAsFixed(2)}, discomfort: ${discomfort.toStringAsFixed(2)}, '
        'isSleepy: $isSleepy, stress: $stressLevel',
        name: 'GeminiAI');

    // EmotionScoresModel에 isSleepy를 직접 담을 수 없으므로
    // gemini_ai_service에서는 EmotionScoresModel만 반환하고
    // isSleepy는 별도 처리를 위해 breedInsight 필드 대신 호출부에서 처리.
    // → analyzeEmotionFromImage/Images 에서 EmotionAnalysisModel로 래핑 시 isSleepy 전달.
    // 임시로 breedInsight 필드에 isSleepy 정보를 전달하는 대신
    // EmotionScoresModel을 반환 후 호출부에서 isSleepy를 별도 파싱하도록
    // _lastIsSleepy 에 캐시한다.
    _lastIsSleepy = isSleepy;

    return EmotionScoresModel(
      happiness:   happiness,
      calm:        calm,
      excitement:  excitement,
      curiosity:   curiosity,
      anxiety:     anxiety,
      fear:        fear,
      sadness:     sadness,
      discomfort:  discomfort,
      stressLevel:   stressLevel,
      activityLevel: activityLevel,
      healthSignal:  healthSignal,
      comfortLevel:  comfortLevel,
      facialFeatures: facialFeatures,
      healthTips:    healthTips,
      breedInsight:  breedInsight,
    );
  }

  // isSleepy를 호출부(EmotionAnalysisBloc 등)에서 읽을 수 있도록 캐시
  bool _lastIsSleepy = false;
  bool get lastIsSleepy => _lastIsSleepy;

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
      try {
        return double.parse(value).clamp(0.0, 1.0);
      } catch (e) {
        log('Failed to parse double from "$value": $e',
            name: 'GeminiAiService');
      }
    }
    return defaultValue;
  }

  int _parseInt(dynamic value, int defaultValue) {
    if (value is num) return value.toInt().clamp(0, 100);
    if (value is String) {
      try {
        return int.parse(value).clamp(0, 100);
      } catch (e) {
        log('Failed to parse int from "$value": $e', name: 'GeminiAiService');
      }
    }
    return defaultValue;
  }
}
