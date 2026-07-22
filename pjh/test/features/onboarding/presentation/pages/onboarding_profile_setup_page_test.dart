import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('첫 프로필은 닉네임·사진만 요청하고 공개 범위를 설명한다', () {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart',
    ).readAsStringSync();

    expect(source, contains("labelText: '닉네임 *'"));
    expect(source, contains('프로필 사진 선택'));
    expect(source, contains('이메일과 로그인 정보는 공개되지 않아요'));
    expect(source, isNot(contains('_bioController')));
    expect(source, isNot(contains('bio:')));
  });
}
