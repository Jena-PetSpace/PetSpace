class ApiConfig {
  // AI 감정분석 API 설정
  static const String emotionApiEndpoint = 'YOUR_AI_EMOTION_API_ENDPOINT';
  static const String emotionApiKey = 'YOUR_AI_EMOTION_API_KEY';

  // Google Gemini API 설정
  static const String geminiApiKey = 'AIzaSyAG9Znz8A78_k3wxJJNZrBm4RDe-8WjAhk';

  // Google Vision API 설정
  static const String googleVisionApiKey =
      'AIzaSyAG9Znz8A78_k3wxJJNZrBm4RDe-8WjAhk';

  // OpenAI API 설정 (선택)
  static const String openAiApiKey = 'YOUR_OPENAI_API_KEY';

  // AWS Rekognition 설정 (선택)
  static const String awsAccessKey = 'YOUR_AWS_ACCESS_KEY';
  static const String awsSecretKey = 'YOUR_AWS_SECRET_KEY';
  static const String awsRegion = 'YOUR_AWS_REGION';

  // 소셜 로그인 설정
  static const String googleClientId =
      '436717619181-57khh827kfg9t5j1oo9tpnloalf7rtb7.apps.googleusercontent.com';
  static const String kakaoAppKey = 'c9e18a9067b1d5b615849d787d7ef05b';

  // API 설정 확인 메서드
  static bool get isEmotionApiConfigured =>
      emotionApiEndpoint != 'YOUR_AI_EMOTION_API_ENDPOINT' &&
      emotionApiKey != 'YOUR_AI_EMOTION_API_KEY';

  static bool get isGeminiConfigured => geminiApiKey != 'YOUR_GEMINI_API_KEY';

  static bool get isGoogleVisionConfigured =>
      googleVisionApiKey != 'YOUR_GOOGLE_VISION_API_KEY';

  static bool get isOpenAiConfigured => openAiApiKey != 'YOUR_OPENAI_API_KEY';

  static bool get isAwsConfigured =>
      awsAccessKey != 'YOUR_AWS_ACCESS_KEY' &&
      awsSecretKey != 'YOUR_AWS_SECRET_KEY';

  static bool get isGoogleLoginConfigured =>
      googleClientId != 'YOUR_GOOGLE_CLIENT_ID';

  static bool get isKakaoLoginConfigured => kakaoAppKey != 'YOUR_KAKAO_APP_KEY';

  // 현재 사용 가능한 기능들
  static List<String> get availableFeatures {
    final features = <String>[];

    if (isEmotionApiConfigured) features.add('AI 감정분석');
    if (isGeminiConfigured) features.add('Google Gemini AI');
    if (isGoogleVisionConfigured) features.add('Google Vision API');
    if (isOpenAiConfigured) features.add('OpenAI API');
    if (isAwsConfigured) features.add('AWS Rekognition');
    if (isGoogleLoginConfigured) features.add('Google 로그인');
    if (isKakaoLoginConfigured) features.add('Kakao 로그인');

    if (features.isEmpty) {
      features.add('데모 모드 (랜덤 결과)');
    }

    return features;
  }

  // 설정 안내 메시지
  static String get configurationGuide => '''
🔧 API 설정이 필요합니다!

현재 데모 모드로 실행 중입니다. 실제 기능을 사용하려면 다음 API 키들을 설정하세요:

1. 감정분석 API:
   - emotionApiEndpoint: AI 감정분석 서버 엔드포인트
   - emotionApiKey: API 인증 키

2. 소셜 로그인:
   - googleClientId: Google OAuth 클라이언트 ID
   - kakaoAppKey: Kakao 개발자 앱 키

3. 선택사항:
   - Google Vision API: 얼굴 감정 인식
   - OpenAI API: GPT 기반 감정 분석
   - AWS Rekognition: AWS 감정 분석

설정 파일: lib/config/api_config.dart
''';
}
