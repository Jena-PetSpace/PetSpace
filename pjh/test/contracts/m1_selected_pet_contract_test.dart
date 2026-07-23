import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String setup;
  late String setupM1;

  setUpAll(() {
    migration = File(
      '../supabase/migrations/20260723042242_m1_selected_pet_contract.sql',
    ).readAsStringSync();
    setup = File('../supabase/petspace_setup.sql').readAsStringSync();
    setupM1 = setup.substring(setup.lastIndexOf('M1 SELECTED PET CONTRACT'));
  });

  test('migration과 fresh setup은 ON DELETE SET NULL FK를 함께 고정한다', () {
    expect(migration, isNot(contains(RegExp(r'^\+', multiLine: true))));
    for (final source in [migration, setup]) {
      expect(source, contains('selected_pet_id'));
      expect(source, contains('REFERENCES public.pets(id)'));
      expect(source, contains('ON DELETE SET NULL'));
    }
  });

  test('조회·변경 RPC는 caller id 없이 auth.uid로만 동작한다', () {
    for (final source in [migration, setupM1]) {
      expect(source, contains('public.get_my_selected_pet_id()'));
      expect(source, contains('public.set_my_selected_pet_id(p_pet_id uuid)'));
      expect(source, contains('v_actor uuid := auth.uid()'));
      expect(source, contains('p.user_id = v_actor'));
      expect(source, isNot(contains('p_user_id')));
      expect(source, isNot(contains('caller_id')));
    }
  });

  test('SECURITY DEFINER RPC는 search_path와 실행 권한을 제한한다', () {
    for (final source in [migration, setupM1]) {
      expect(source, contains("SET search_path = ''"));
      expect(
        source,
        contains(
          'REVOKE ALL ON FUNCTION public.get_my_selected_pet_id()\n  FROM PUBLIC, anon, authenticated;',
        ),
      );
      expect(
        source,
        contains(
          'REVOKE ALL ON FUNCTION public.set_my_selected_pet_id(uuid)\n  FROM PUBLIC, anon, authenticated;',
        ),
      );
      expect(source, contains('TO authenticated;'));
    }
  });
}
