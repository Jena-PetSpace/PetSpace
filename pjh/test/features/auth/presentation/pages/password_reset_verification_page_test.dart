import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('인증 실패 시 원문 오류를 숨기고 입력 코드를 임의 초기화하지 않는다', () {
    final source = File(
      'lib/features/auth/presentation/pages/password_reset_verification_page.dart',
    ).readAsStringSync();
    final authFailure = source.substring(
      source.indexOf('} on AuthException catch'),
      source.indexOf('void _onCodeChanged'),
    );

    expect(authFailure, contains('인증을 완료하지 못했어요'));
    expect(authFailure, isNot(contains("'인증 실패: \${e.message}'")));
    expect(authFailure, isNot(contains('controller.clear()')));
  });
}
