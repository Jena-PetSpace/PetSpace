import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('재설정 요청은 계정 존재 여부를 공개 메시지로 구분하지 않는다', () {
    final source = File(
      'lib/features/auth/presentation/pages/password_reset_request_page.dart',
    ).readAsStringSync();

    expect(source, contains('계정 존재 여부를'));
    expect(source, contains('가입 여부는 화면에 표시하지 않아요'));
    expect(source, isNot(contains("return '등록되지 않은 이메일입니다.'")));
  });
}
