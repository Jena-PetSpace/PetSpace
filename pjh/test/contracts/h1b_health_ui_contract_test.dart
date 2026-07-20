import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relativePath) =>
    File('../$relativePath').readAsStringSync();

void main() {
  test('health main keeps all six filters and one selected brand color', () {
    final main = _read(
      'pjh/lib/features/health/presentation/pages/health_main_page.dart',
    );

    for (final label in ['전체', '백신', '검진', '체중', '투약', '수술']) {
      expect(main, contains(label));
    }
    expect(main, contains('selected: isSelected'));
    expect(main, contains('AppTheme.actionBase'));
    expect(main, contains('BoxConstraints(minWidth: 44, minHeight: 44)'));
    expect(main, contains('height: 44,'));
    expect(main, isNot(contains('height: 44.h')));
    expect(main, isNot(contains('return GestureDetector(')));
  });

  test('health main separates states and exposes one health tools entry', () {
    final main = _read(
      'pjh/lib/features/health/presentation/pages/health_main_page.dart',
    );

    expect(main, contains("tooltip: '건강 도구'"));
    expect(main, contains("'건강 알림'"));
    expect(main, contains("pageContext.push('/health/alert-settings')"));
    expect(main, contains("'건강 리포트'"));
    expect(main, contains("'반려동물을 먼저 등록해주세요'"));
    expect(main, contains("'아직 건강 기록이 없어요'"));
    expect(main, contains("'건강 기록을 불러오지 못했어요'"));
  });

  test('editor keeps five record types and 44dp type controls', () {
    final sheets = _read(
      'pjh/lib/features/health/presentation/widgets/health_record_sheets.dart',
    );

    expect(sheets, contains('height: 44,'));
    expect(sheets, isNot(contains('height: 44.h')));
    expect(sheets, contains("'다음 예정일 해제'"));
    expect(sheets, contains('!nextDate!.isBefore(firstDate)'));
    expect(sheets, contains('return AppTheme.actionBase'));
  });
}
