import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('인증·온보딩 presentation은 응답·예외·token을 원문 로그로 남기지 않는다', () {
    const paths = [
      'lib/features/onboarding/presentation/pages/onboarding_login_page.dart',
      'lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart',
      'lib/features/auth/presentation/pages/password_reset_request_page.dart',
      'lib/features/auth/presentation/pages/password_reset_verification_page.dart',
      'lib/features/auth/presentation/pages/password_reset_new_password_page.dart',
      'lib/core/navigation/app_router.dart',
    ];
    final source =
        paths.map((path) => File(path).readAsStringSync()).join('\n');

    expect(source, isNot(contains('response.toString()')));
    expect(source, isNot(contains("developer.log('재발송")));
    expect(source, isNot(contains("'인증 실패: \${e.message}'")));
    expect(source, isNot(contains("'인증 실패: \${e.toString()}'")));
    expect(source, isNot(contains('error: e')));
    expect(source, isNot(contains("log('User ID:")));
  });
}
