import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final preview = File(
    'lib/features/health/presentation/pages/health_pdf_preview_page.dart',
  ).readAsStringSync();
  final generator = File(
    'lib/features/health/presentation/widgets/health_pdf_generator.dart',
  ).readAsStringSync();

  test('PDF preview exposes save/share scope and keeps failure local', () {
    expect(preview, contains('저장하거나 공유할 수 있어요'));
    expect(preview, contains('의료 진단을 대신하지 않습니다.'));
    expect(preview, contains('기록은 그대로 유지됩니다.'));
    expect(preview, contains("actionLabel: '다시 생성'"));
    expect(preview, contains('setState(() => _generation++)'));
    expect(preview, contains('canDebug: false'));
  });

  test('generated report includes a reference-only disclaimer', () {
    expect(generator, contains('보호자가 입력한 건강 기록을 정리한 참고 자료'));
    expect(generator, contains('수의사의 판단을 대신하지 않습니다.'));
    expect(generator.toLowerCase(), isNot(contains('confidence')));
    expect(generator, isNot(contains('신뢰도')));
  });
}
