import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('완료 화면은 단일 주 CTA와 절제된 신뢰 문구를 사용한다', () {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_complete_page.dart',
    ).readAsStringSync();

    expect(source, contains('준비가 완료됐어요'));
    expect(source, contains('PetSpace 시작하기'));
    expect(source, contains('첫 감정 분석부터 해보기'));
    expect(source, isNot(contains('환영합니다! 🎉')));
    expect(source, isNot(contains('온보딩 완료!')));
  });
}
