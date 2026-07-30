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
    expect(main, contains("key: const Key('health_record_filter_strip')"));
    expect(main, contains('SingleChildScrollView('));
    expect(main, isNot(contains('height: 44,')));
    expect(main, contains('BoxConstraints(minHeight: 52)'));
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

  test('editor is a root full-screen task with five retained type inputs', () {
    final sheets = _read(
      'pjh/lib/features/health/presentation/widgets/health_record_sheets.dart',
    );
    final editor = _read(
      'pjh/lib/features/health/presentation/pages/health_record_editor_page.dart',
    );
    final form = _read(
      'pjh/lib/features/health/presentation/widgets/health_record_form.dart',
    );

    expect(sheets, contains('rootNavigator: true'));
    expect(sheets, contains('HealthRecordEditorPage('));
    expect(sheets, isNot(contains('showModalBottomSheet(')));
    expect(form, contains("key: const Key('health_record_type_selector')"));
    expect(form, contains('SingleChildScrollView('));
    expect(form, isNot(contains('height: 44,')));
    for (final value in [
      'HealthRecordType.vaccination',
      'HealthRecordType.checkup',
      'HealthRecordType.weight',
      'HealthRecordType.medication',
      'HealthRecordType.surgery',
    ]) {
      expect(form, contains(value));
    }
    expect(editor, contains('백신 종류를 입력해주세요.'));
    expect(editor, contains('0보다 큰 체중을 kg 단위로 입력해주세요.'));
    expect(editor, contains('약 이름을 입력해주세요.'));
    expect(editor, contains('수술명을 입력해주세요.'));
    expect(editor, contains('nextDate!.isBefore(_recordDate)'));
    expect(editor, contains('의료 진단'));
  });
}
