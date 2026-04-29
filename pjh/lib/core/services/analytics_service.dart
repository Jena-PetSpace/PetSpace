import 'dart:developer';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// PetSpace 핵심 Analytics 이벤트 서비스
///
/// Firebase가 초기화되지 않은 환경(iOS 개발, 미지원 플랫폼)에서는
/// 에러 없이 조용히 스킵합니다.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _ready = false;

  void initialize() {
    try {
      _analytics = FirebaseAnalytics.instance;
      _ready = true;
      log('✅ AnalyticsService 초기화 완료', name: 'Analytics');
    } catch (e) {
      log('⚠️ AnalyticsService 초기화 실패: $e', name: 'Analytics');
    }
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_ready || _analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: params);
    } catch (e) {
      log('Analytics log error [$name]: $e', name: 'Analytics');
    }
  }

  // ── 사용자 속성 ────────────────────────────────────────

  Future<void> setUserId(String userId) async {
    if (!_ready || _analytics == null) return;
    try {
      await _analytics!.setUserId(id: userId);
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (_) {}
  }

  // ── 1. 회원가입 완료 ────────────────────────────────────
  Future<void> logSignUp({required String method}) =>
      _log('sign_up', {'method': method});

  // ── 2. 로그인 ───────────────────────────────────────────
  Future<void> logLogin({required String method}) =>
      _log('login', {'method': method});

  // ── 3. 감정 분석 시작 ────────────────────────────────────
  Future<void> logEmotionAnalysisStart({
    required int imageCount,
    String? petType,
  }) =>
      _log('emotion_analysis_start', {
        'image_count': imageCount,
        if (petType != null) 'pet_type': petType,
      });

  // ── 4. 감정 분석 완료 ────────────────────────────────────
  Future<void> logEmotionAnalysisComplete({
    required String dominantEmotion,
    required int imageCount,
  }) =>
      _log('emotion_analysis_complete', {
        'dominant_emotion': dominantEmotion,
        'image_count': imageCount,
      });

  // ── 5. 건강 분석 시작 ────────────────────────────────────
  Future<void> logHealthAnalysisStart({
    required String area,
    required int imageCount,
  }) =>
      _log('health_analysis_start', {
        'area': area,
        'image_count': imageCount,
      });

  // ── 6. 건강 분석 완료 ────────────────────────────────────
  Future<void> logHealthAnalysisComplete({
    required String area,
    required int score,
    required String status,
  }) =>
      _log('health_analysis_complete', {
        'area': area,
        'score': score,
        'status': status,
      });

  // ── 7. 게시물 작성 ──────────────────────────────────────
  Future<void> logPostCreated({
    required String postType,
    required int imageCount,
  }) =>
      _log('post_created', {
        'post_type': postType,
        'image_count': imageCount,
      });

  // ── 8. 분석 결과 피드 공유 ───────────────────────────────
  Future<void> logAnalysisSharedToFeed({required String analysisType}) =>
      _log('analysis_shared_to_feed', {'analysis_type': analysisType});

  // ── 9. 반려동물 등록 ────────────────────────────────────
  Future<void> logPetRegistered({required String petType}) =>
      _log('pet_registered', {'pet_type': petType});

  // ── 10. 팔로우 ──────────────────────────────────────────
  Future<void> logFollow() => _log('follow_user');

  // ── 11. 온보딩 완료 ─────────────────────────────────────
  Future<void> logOnboardingComplete() => _log('onboarding_complete');

  // ── 12. 알림 허용 ───────────────────────────────────────
  Future<void> logNotificationPermissionGranted() =>
      _log('notification_permission_granted');
}
