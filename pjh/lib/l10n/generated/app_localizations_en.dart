// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PetSpace';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authSignupTitle => 'Sign up';

  @override
  String get authSignInWithApple => 'Sign in with Apple';

  @override
  String get authSignInWithGoogle => 'Sign in with Google';

  @override
  String get authSignInWithKakao => 'Sign in with Kakao';

  @override
  String get feedEmptyTitle => 'No posts yet';

  @override
  String get feedEmptyAction => 'Create your first post';

  @override
  String get emotionDisclaimer =>
      'This analysis is an AI-based estimation and does not replace veterinary diagnosis.';

  @override
  String get communityGuidelinesTitle => 'Community Guidelines';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';
}
