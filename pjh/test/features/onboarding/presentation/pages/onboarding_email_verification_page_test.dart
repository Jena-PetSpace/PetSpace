import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('이메일 인증 화면은 토큰·응답·원문 예외를 로그나 UI에 노출하지 않는다', () {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart',
    ).readAsStringSync();

    expect(source, contains('인증을 완료하지 못했어요'));
    expect(source, isNot(contains('response.toString()')));
    expect(source, isNot(contains("developer.log('재발송")));
    expect(source, isNot(contains("'인증 실패: \${e.toString()}'")));
    expect(source, isNot(contains("'인증 실패: \${e.message}'")));
  });
}
