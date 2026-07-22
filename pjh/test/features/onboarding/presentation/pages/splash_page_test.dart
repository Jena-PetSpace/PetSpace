import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('스플래시는 제한 시간과 안전한 asset 오류 로그를 사용한다', () {
    final source = File(
      'lib/features/onboarding/presentation/pages/splash_page.dart',
    ).readAsStringSync();

    expect(source, contains('Duration(seconds: 3)'));
    expect(source, contains("log('Lottie asset load failed'"));
    expect(source, isNot(contains('Lottie 로드 실패: \$error')));
    expect(source, contains('current is AuthAuthenticated ||'));
    expect(source, contains('current is AuthUnauthenticated'));
  });
}
