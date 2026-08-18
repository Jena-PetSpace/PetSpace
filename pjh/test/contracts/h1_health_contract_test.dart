import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relativePath) =>
    File('../$relativePath').readAsStringSync();

void main() {
  test('upcoming records are scoped to one pet and one canonical due-date path',
      () {
    final source = _read(
      'pjh/lib/features/health/data/repositories/health_repository_impl.dart',
    );

    expect(source, contains(".eq('pet_id', petId)"));
    expect(source, contains('next_date.gte.'));
    expect(source, contains('next_date.is.null'));
    expect(source, contains('record_date.gte.'));
    expect(source, contains('final due = record.dueDate'));
  });

  test('health repository never returns raw database or exception text', () {
    final source = _read(
      'pjh/lib/features/health/data/repositories/health_repository_impl.dart',
    );

    expect(source, isNot(contains('e.toString()')));
    expect(source, isNot(contains(r'${e.message}')));
    expect(source, isNot(contains('DB 오류:')));
  });

  test('delete success requires an actually removed health record', () {
    final source = _read(
      'pjh/lib/features/health/data/repositories/health_repository_impl.dart',
    );

    expect(source, contains(".select('id')"));
    expect(source, contains('if ((response as List).isEmpty)'));
  });

  test('fresh setup and L1 migration enforce pet owner on every operation', () {
    final setup = _read('supabase/petspace_setup.sql');
    final migration =
        _read('supabase/manual_sql/history/L1_health_record_owner_contract.sql');

    for (final sql in [setup, migration]) {
      expect(sql, contains('pets.id = health_records.pet_id'));
      expect(sql, contains('pets.user_id = auth.uid()'));
      expect(sql, contains('FOR SELECT'));
      expect(sql, contains('FOR INSERT'));
      expect(sql, contains('FOR UPDATE'));
      expect(sql, contains('FOR DELETE'));
      expect(sql, contains('WITH CHECK'));
    }
  });
}
