// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '펫페이스';

  @override
  String get commonOk => '확인';

  @override
  String get commonCancel => '취소';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonClose => '닫기';

  @override
  String get commonSave => '저장';

  @override
  String get commonDelete => '삭제';

  @override
  String get authLoginTitle => '로그인';

  @override
  String get authSignupTitle => '회원가입';

  @override
  String get authSignInWithApple => 'Apple로 로그인';

  @override
  String get authSignInWithGoogle => 'Google 계정으로 로그인하기';

  @override
  String get authSignInWithKakao => '카카오톡 계정으로 로그인하기';

  @override
  String get feedEmptyTitle => '아직 게시물이 없어요';

  @override
  String get feedEmptyAction => '첫 게시물 작성';

  @override
  String get emotionDisclaimer =>
      '본 분석은 AI가 사진을 기반으로 추정한 결과로, 수의학적 진단을 대체하지 않습니다.';

  @override
  String get communityGuidelinesTitle => '커뮤니티 가이드라인';

  @override
  String get privacyPolicyTitle => '개인정보처리방침';
}
