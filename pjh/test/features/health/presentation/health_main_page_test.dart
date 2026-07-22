import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/health/presentation/pages/health_main_page.dart',
  ).readAsStringSync();

  test('health root prioritizes next care and a full-width add action', () {
    final nextCare = source.indexOf("title: '다음 케어'");
    final addAction = source.indexOf("label: const Text('건강 기록 추가')");
    final recent = source.indexOf("title: '최근 기록'");

    expect(nextCare, greaterThan(-1));
    expect(addAction, greaterThan(nextCare));
    expect(recent, greaterThan(addAction));
    expect(source, contains("key: const Key('health_add_record_cta')"));
    expect(source, isNot(contains('floatingActionButton:')));
    expect(source, contains('alerts.first'));
    expect(source, contains('자동 알림 제공 여부와는 별개입니다.'));
  });

  test('health states retain the selected pet and hide internal errors', () {
    expect(source, contains('_buildPetBar(pet)'));
    expect(source, contains('health_loading_skeleton_'));
    expect(source, contains('선택한 반려동물은 유지됩니다.'));
    expect(source, contains('최근 기록은 그대로 유지됩니다.'));
    expect(source, isNot(contains('_buildErrorState(String message)')));
    expect(source, isNot(contains('message: state.message')));
  });

  test('health change and PDF stay reference-only and record-gated', () {
    expect(source, contains("title: '건강 변화'"));
    expect(source, contains('WeightTrendChart(records: state.records)'));
    expect(source, contains("key: const Key('health_pdf_preview_button')"));
    expect(source, contains('onPressed: enabled'));
    expect(source, contains('미리 확인한 뒤 기기에 저장하거나 공유'));
  });
}
