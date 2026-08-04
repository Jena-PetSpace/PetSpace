import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String relativePath) {
  return File(relativePath).readAsStringSync();
}

void main() {
  test('fresh setup and E1 migration keep the MBTI history contract aligned',
      () {
    final setup = _read('../supabase/petspace_setup.sql');
    final migration = _read('../supabase/manual_sql/history/E1_pet_mbti.sql');

    for (final sql in <String>[setup, migration]) {
      expect(sql, contains('pet_mbti_results'));
      expect(sql, contains('current_mbti_type'));
      expect(sql, contains('current_mbti_updated_at'));
      expect(sql, contains('idx_pet_mbti_results_pet_created'));
      expect(sql, contains('Users can view own pet mbti results'));
      expect(sql, contains('Users can insert own pet mbti results'));
      expect(sql, contains('Users can delete own pet mbti results'));
      expect(sql, isNot(contains('Users can update own pet mbti results')));
      expect(sql, contains('p.user_id = auth.uid()'));
    }
  });
}
