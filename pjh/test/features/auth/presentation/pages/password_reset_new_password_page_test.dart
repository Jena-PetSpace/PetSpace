import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('새 비밀번호는 8자·영문·숫자 계약과 안전한 공개 오류를 사용한다', () {
    final source = File(
      'lib/features/auth/presentation/pages/password_reset_new_password_page.dart',
    ).readAsStringSync();

    expect(source, contains("value.length < 8"));
    expect(source, contains("RegExp(r'[A-Za-z]')"));
    expect(source, contains("RegExp(r'\\d')"));
    expect(source, contains('비밀번호 변경에 실패했습니다. 잠시 후 다시 시도해주세요.'));
    expect(source, isNot(contains("'비밀번호 변경 실패: \$e'")));
  });
}
