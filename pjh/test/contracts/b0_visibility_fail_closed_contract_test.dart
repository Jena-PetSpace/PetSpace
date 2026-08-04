import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n');

String _match(String source, RegExp pattern) {
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: pattern.pattern);
  return match!.group(0)!;
}

void main() {
  const migrationPath =
      '../supabase/migrations/20260804_b0_post_visibility_fail_closed.sql';

  test('direct posts SELECT는 auth.uid 기반 RESTRICTIVE owner/public guard다', () {
    final migration = _read(migrationPath);
    final setup = _read('../supabase/petspace_setup.sql');

    for (final source in [migration, setup]) {
      final policy = _match(
        source,
        RegExp(r'CREATE POLICY posts_privacy_fail_closed[\s\S]*?;'),
      );
      expect(policy, contains('AS RESTRICTIVE'));
      expect(policy, contains('FOR SELECT'));
      expect(policy, contains('TO authenticated'));
      expect(policy, contains('author_id = auth.uid()'));
      expect(policy, contains('OR is_private IS FALSE'));
      expect(policy, isNot(contains('FOR ALL')));
      expect(policy, isNot(contains('TO anon')));
    }
    expect(migration, contains('BEGIN;'));
    expect(migration, contains('COMMIT;'));
    expect(migration, contains('DROP POLICY IF EXISTS'));
    expect(migration, isNot(contains('SET NOT NULL')));
    expect(migration, isNot(contains('UPDATE public.posts')));
  });

  test('익명·자식 테이블·hashtag 집계 우회 경로를 닫는다', () {
    final migration = _read(migrationPath);
    final setup = _read('../supabase/petspace_setup.sql');
    // K1은 canonical setup에 통합돼 별도 migration 파일을 보관하지 않는다.
    final k1 = setup;

    final k1PostsPolicy = _match(
      k1,
      RegExp(r'CREATE POLICY posts_select_visible[\s\S]*?;'),
    );
    expect(k1PostsPolicy, contains('FOR SELECT TO authenticated'));
    expect(k1PostsPolicy, isNot(contains('TO anon')));

    for (final policyName in [
      'comments_select_visible',
      'likes_select_visible',
      'comment_likes_select_visible',
    ]) {
      final block = _match(
        setup,
        RegExp('CREATE POLICY $policyName[\\s\\S]*?;'),
      );
      expect(block, contains('TO authenticated'));
      expect(block, contains('public.posts'));
    }

    for (final functionName in [
      'get_popular_hashtags',
      'get_trending_hashtags',
    ]) {
      for (final source in [migration, setup]) {
        final block = _match(
          source,
          RegExp(
            'CREATE OR REPLACE FUNCTION (?:public\\.)?$functionName'
            r'\([\s\S]*?\n\$\$;',
          ),
        );
        expect(block, contains('SECURITY DEFINER'));
        expect(block, contains('SET search_path = public'));
        expect(block, contains('is_private IS FALSE'));
      }
    }
    for (final source in [migration, setup]) {
      expect(
        source,
        contains(
          'REVOKE ALL ON FUNCTION public.get_popular_hashtags(integer)',
        ),
      );
      expect(
        source,
        contains(
          'REVOKE ALL ON FUNCTION public.get_trending_hashtags(integer, integer)',
        ),
      );
      expect(source, contains('FROM PUBLIC, anon;'));
      expect(
        source,
        contains(
          'GRANT EXECUTE ON FUNCTION public.get_popular_hashtags(integer)',
        ),
      );
    }
  });

  test('SECURITY DEFINER feed RPC도 caller id가 아닌 auth.uid를 정본으로 쓴다', () {
    final migration = _read(migrationPath);
    final setup = _read('../supabase/petspace_setup.sql');
    // K1은 canonical setup에 통합돼 별도 migration 파일을 보관하지 않는다.
    final k1 = setup;

    for (final source in [migration, setup]) {
      expect(source,
          contains('CREATE OR REPLACE FUNCTION public.get_feed_posts('));
      expect(source, contains('DECLARE v_actor uuid := auth.uid();'));
      expect(
        source,
        contains('AND (p.author_id = v_actor OR p.is_private IS FALSE)'),
      );
      expect(source, contains('LANGUAGE plpgsql SECURITY DEFINER'));
      expect(source, contains('SET search_path = public'));
      expect(source, contains('user_uuid <> v_actor'));
    }

    expect(k1, contains('private.user_is_active_internal(p.author_id)'));
    expect(k1,
        contains('private.mutually_blocked_internal(v_actor, p.author_id)'));
    expect(k1,
        contains('CREATE OR REPLACE FUNCTION public.get_recommended_posts('));
    expect(k1,
        contains('CREATE OR REPLACE FUNCTION public.get_posts_by_hashtag('));
    expect(k1,
        contains('CREATE OR REPLACE FUNCTION public.get_posts_by_location('));
  });

  test('migration과 canonical setup의 feed signature/return shape가 같다', () {
    final migration = _read(migrationPath);
    final setup = _read('../supabase/petspace_setup.sql');

    const signature = '''public.get_feed_posts(
  user_uuid uuid,
  limit_count integer DEFAULT 20,
  offset_count integer DEFAULT 0
)''';
    const returnTail = '''created_at timestamptz,
  is_liked boolean
)''';
    for (final source in [migration, setup]) {
      expect(source, contains(signature));
      expect(source, contains(returnTail));
    }
  });
}
