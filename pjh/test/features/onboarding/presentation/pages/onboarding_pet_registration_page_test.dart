import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('첫 반려동물은 이름·종류만 필수이며 나중에 등록할 수 있다', () {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('skip-first-pet')"));
    expect(source, contains("const Text('나중에')"));
    expect(source, contains("ValueKey('first-pet-name')"));
    expect(source, contains('강아지 또는 고양이를 선택해주세요.'));
    expect(source, contains('생년월일'));
    expect(source, contains('자세한 정보는 MY에서 나중에 추가'));
    expect(source, isNot(contains("labelText: '성별'")));
    expect(source, isNot(contains("labelText: '품종'")));
  });
}
