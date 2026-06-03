import 'dart:developer';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// PetSpace 핵심 Analytics 이벤트 서비스
///
/// Firebase가 초기화되지 않은 환경(iOS 개발, 미지원 플랫폼)에서는
/// 에러 없이 조용히 스킵합니다.
///
/// [iOS App Tracking Transparency 정책 — P1-8]
/// 본 서비스는 광고 식별자(IDFA) / 광고 SDK / 크로스앱 트래킹을 사용하지 않으며,
/// Firebase Analytics 기본 설정만으로 동작합니다. 따라서 `NSUserTrackingUsageDescription`
/// 미선언 + ATT 프롬프트 미호출이 정상이며, Apple 심사 시에도 트래킹 답변을 "아니오" 로
/// 제출합니다. PrivacyInfo.xcprivacy 의 `NSPrivacyTracking = false` 와 동기화 유지.
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

  // ── 13. 반려동물 MBTI (익명 집계 전용) ─────────────────────
  // ⚠️ 개인정보 최소화: pet 이름·사진 등 식별 정보는 파라미터에 넣지 않는다.
  //    species(dog/cat/etc), 유형코드, 문항 인덱스, 완주 여부 등 집계용만.

  /// 검사 시작
  Future<void> logMbtiStart({required String species}) =>
      _log('mbti_start', {'species': species});

  /// 문항 이탈(중간에 검사 화면을 떠남). answered: 응답한 문항 수.
  Future<void> logMbtiAbandon({
    required String species,
    required int answered,
    required int total,
  }) =>
      _log('mbti_abandon', {
        'species': species,
        'answered': answered,
        'total': total,
      });

  /// 완주(채점 성공). 완주율 집계용. type_code 로 유형 분포도 집계.
  Future<void> logMbtiComplete({
    required String species,
    required String typeCode,
  }) =>
      _log('mbti_complete', {
        'species': species,
        'type_code': typeCode,
      });

  /// 결과 공유 완료. include_photo: 사진 포함 여부(집계용 bool→int).
  Future<void> logMbtiShare({
    required String typeCode,
    required bool includePhoto,
  }) =>
      _log('mbti_share', {
        'type_code': typeCode,
        'include_photo': includePhoto ? 1 : 0,
      });
}
