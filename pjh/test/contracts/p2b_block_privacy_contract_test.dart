import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '../supabase/migrations/K1_block_privacy_contract.sql',
  ).readAsStringSync().replaceAll('\r\n', '\n');
  final setup = File(
    '../supabase/petspace_setup.sql',
  ).readAsStringSync().replaceAll('\r\n', '\n');
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
  final lib = dartFiles.map((file) => file.readAsStringSync()).join('\n');
  final chat = File(
    'lib/features/chat/data/datasources/chat_remote_data_source.dart',
  ).readAsStringSync();
  final auth = File(
    'lib/features/auth/data/repositories/auth_repository_impl.dart',
  ).readAsStringSync();
  final privacy = File(
    'lib/features/profile/presentation/pages/privacy_settings_page.dart',
  ).readAsStringSync();
  final pushFunction = File(
    '../supabase/functions/send-push-notification/index.ts',
  ).readAsStringSync();

  test('K1 fixes privileged functions to auth.uid and search_path', () {
    for (final name in [
      'block_user',
      'unblock_user',
      'get_blocked_users',
      'get_my_user_profile',
      'ensure_my_user_profile',
      'get_total_unread_count',
      'get_room_unread_count',
      'get_or_create_direct_chat',
      'create_group_chat',
      'notification_delivery_allowed',
    ]) {
      expect(migration, contains('FUNCTION public.$name'));
    }
    expect(migration, contains('auth.uid()'));
    expect(migration, contains('SET search_path = public'));
  });

  test('legacy caller-id functions are revoked from every client role', () {
    for (final signature in [
      'get_blocked_user_ids(uuid)',
      'is_mutually_blocked(uuid, uuid)',
      'get_total_unread_count(uuid)',
      'get_room_unread_count(uuid, uuid)',
      'find_direct_chat(uuid, uuid)',
    ]) {
      expect(migration, contains(signature));
    }
    expect(migration, contains('FROM PUBLIC, anon, authenticated'));
  });

  test('block is bidirectional for follows and unblock does not restore', () {
    expect(
      migration,
      contains('(follower_id = p_blocked_id AND following_id = v_actor)'),
    );
    final unblock = migration.substring(
      migration.indexOf('public.unblock_user'),
    );
    expect(
      unblock.split(r'$$;').first,
      isNot(contains('INSERT INTO public.follows')),
    );
    expect(
      migration,
      contains('REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_blocks'),
    );
    expect(
      migration,
      contains(
        'DROP POLICY IF EXISTS "Users can create blocks for themselves"',
      ),
    );
  });

  test('blocked list uses composite cursor and bounded limit', () {
    expect(
      migration,
      contains('(ub.created_at, ub.id) < (p_before_created_at, p_before_id)'),
    );
    expect(migration, contains('least(coalesce(p_limit, 20), 20)'));
  });

  test('public projections do not request email or wildcard users', () {
    expect(
      RegExp(
        r"from\('users'\)[\s\S]{0,100}\.select\((?:\)|'\*')",
      ).hasMatch(lib),
      isFalse,
    );
    final publicSources = [
      'lib/features/social/data/datasources/social_remote_data_source_impl_follow.dart',
      'lib/features/chat/data/datasources/chat_remote_data_source.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(RegExp(r'select\([^)]*email').hasMatch(publicSources), isFalse);
  });

  test('users access is column-scoped and fresh setup preserves K1', () {
    expect(
      migration,
      contains(
        'REVOKE SELECT ON TABLE public.users FROM PUBLIC, anon, authenticated',
      ),
    );
    expect(migration, isNot(contains('GRANT SELECT ON TABLE public.users')));
    final grant = migration.substring(
      migration.indexOf('GRANT SELECT ('),
      migration.indexOf('ON TABLE public.users TO authenticated'),
    );
    expect(grant, isNot(contains('cover_image_url')));
    // Fresh setup may append stricter privacy guards after K1. Keep this
    // assertion semantic so an additive fail-closed contract does not require
    // byte-for-byte equality with the older K1 migration.
    for (final marker in [
      '-- MY-CLOSE P2B / K1: auth.uid()-anchored block and privacy contract.',
      'CREATE OR REPLACE FUNCTION public.block_user',
      'CREATE OR REPLACE FUNCTION public.unblock_user',
      'CREATE OR REPLACE FUNCTION public.get_blocked_users',
      'CREATE OR REPLACE FUNCTION public.ensure_my_user_profile',
      'CREATE OR REPLACE FUNCTION public.get_total_unread_count',
      'CREATE OR REPLACE FUNCTION public.get_or_create_direct_chat',
      'CREATE OR REPLACE FUNCTION public.notification_delivery_allowed',
      'REVOKE SELECT ON TABLE public.users FROM PUBLIC, anon, authenticated',
      'SET search_path = public',
      'auth.uid()',
    ]) {
      expect(setup, contains(marker));
    }
  });

  test(
    'social login creates the private profile only through auth uid RPC',
    () {
      expect(auth, contains("'ensure_my_user_profile'"));
      expect(auth, isNot(contains(".from('users').upsert")));
      final ensureProfile = migration.substring(
        migration.indexOf('FUNCTION public.ensure_my_user_profile'),
        migration.indexOf(
          'REVOKE ALL ON FUNCTION public.ensure_my_user_profile',
        ),
      );
      expect(ensureProfile, contains('v_actor uuid := auth.uid()'));
      expect(ensureProfile, contains('FROM auth.users au'));
      expect(ensureProfile, isNot(contains('p_email')));
    },
  );

  test('policy helpers live outside PostgREST with RLS call permission', () {
    expect(migration, contains('CREATE SCHEMA IF NOT EXISTS private'));
    expect(
      migration,
      contains('GRANT USAGE ON SCHEMA private TO authenticated'),
    );
    for (final helper in [
      'mutually_blocked_internal(uuid, uuid)',
      'user_is_active_internal(uuid)',
      'direct_chat_allowed_internal(uuid, uuid)',
      'reply_target_allowed_internal(uuid, uuid, uuid)',
      'is_room_member(uuid, uuid)',
      'can_manage_group_participants(uuid, uuid)',
    ]) {
      expect(migration, contains('FUNCTION private.$helper'));
      expect(migration, contains('GRANT EXECUTE ON FUNCTION private.$helper'));
    }
    expect(
      migration,
      contains('REVOKE ALL ON FUNCTION public.is_room_member(uuid, uuid)'),
    );
  });

  test('every direct users select stays inside the public allowlist', () {
    const allowed = {
      'id',
      'display_name',
      'username',
      'photo_url',
      'bio',
      'created_at',
      'updated_at',
    };
    final usersPattern = RegExp(r"from\('users'\)");
    final selectPattern = RegExp(r"\.select\(\s*'([^']*)'");
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final usersMatch in usersPattern.allMatches(source)) {
        final nextQuery = source.indexOf('.from(', usersMatch.end);
        final segment = source.substring(
          usersMatch.start,
          nextQuery < 0 ? source.length : nextQuery,
        );
        final selectMatch = selectPattern.firstMatch(segment);
        if (selectMatch == null) continue;
        final requested = selectMatch
            .group(1)!
            .split(',')
            .map((column) => column.trim())
            .where((column) => column.isNotEmpty);
        expect(
          requested.every(allowed.contains),
          isTrue,
          reason: '${file.path}: ${selectMatch.group(1)}',
        );
      }
    }
  });

  test('read and write policies close every mutual-block boundary', () {
    for (final policy in [
      'posts_select_visible',
      'comments_select_visible',
      'follows_select_visible',
      'likes_select_visible',
      'likes_insert_unblocked',
      'comments_insert_unblocked',
      'comment_likes_select_visible',
      'comment_likes_insert_unblocked',
      'notifications_select_own_unblocked',
      'chat_rooms_select_visible',
      'chat_participants_select_visible',
      'chat_participants_insert_unblocked',
      'chat_messages_select_visible',
      'chat_messages_insert_unblocked',
    ]) {
      expect(migration, contains('POLICY $policy'));
    }
    for (final legacyPolicy in [
      '"Users can view likes"',
      '"Users can view all comment likes"',
      '"Users can view own notifications"',
      '"Users can view rooms they participate in"',
      '"Users can view participants of their rooms"',
      '"Users can send messages to rooms they belong to"',
    ]) {
      expect(migration, contains('DROP POLICY IF EXISTS $legacyPolicy'));
    }
    expect(migration, contains('deleted_at IS NULL'));
    expect(migration, contains('user_is_active_internal'));
    expect(migration, contains('direct_chat_allowed_internal'));
  });

  test(
    'notification creation and delivery both enforce the block contract',
    () {
      expect(migration, contains("nullif(btrim(p_type), '') IS NULL"));
      expect(migration, contains("nullif(btrim(p_title), '') IS NULL"));
      expect(migration, contains("nullif(btrim(p_body), '') IS NULL"));
      expect(migration, contains('notification_delivery_allowed'));
      expect(
        migration,
        contains(
          'p_sender_id IS NOT NULL\n'
          '    AND private.mutually_blocked_internal(p_user_id, p_sender_id)',
        ),
      );
    },
  );

  test('legacy discovery signatures are auth.uid anchored replacements', () {
    for (final name in [
      'get_feed_posts',
      'get_recommended_posts',
      'get_posts_by_hashtag',
      'get_posts_by_location',
    ]) {
      final start = migration.indexOf('FUNCTION public.$name');
      expect(start, greaterThanOrEqualTo(0));
      final body = migration.substring(start, migration.indexOf(r'$$;', start));
      expect(body, contains('auth.uid()'));
      expect(body, contains('request not allowed'));
    }
    expect(migration, contains('TO authenticated'));
  });

  test('reply validation is non-recursive and post-bound', () {
    expect(migration, contains('reply_target_allowed_internal'));
    expect(migration, contains('parent.post_id = p_post_id'));
    final insertPolicy = migration.substring(
      migration.indexOf('CREATE POLICY comments_insert_unblocked'),
      migration.indexOf(
        'DROP POLICY IF EXISTS "Users can view all comment likes"',
      ),
    );
    expect(insertPolicy, contains('reply_target_allowed_internal'));
    expect(insertPolicy, isNot(contains('FROM public.comments parent')));
  });

  test('chat hidden cursor stops pagination and direct room is atomic', () {
    expect(chat, contains('.maybeSingle()'));
    expect(chat, contains('if (lastMsg == null) return const []'));
    expect(chat, contains("'get_or_create_direct_chat'"));
    expect(chat, isNot(contains("'find_direct_chat'")));
    expect(chat, contains("select('content, type, sender_id, created_at')"));
    expect(chat, isNot(contains(".order('last_message_at'")));
    expect(migration, contains('chat_rooms_update_admin'));
    expect(
      migration,
      contains(
        'private.can_manage_group_participants(chat_rooms.id, auth.uid())',
      ),
    );
    expect(
      migration,
      contains(
        'REVOKE UPDATE ON TABLE public.chat_rooms FROM PUBLIC, anon, authenticated',
      ),
    );
    expect(migration, contains('GRANT UPDATE (name, description, avatar_url)'));
    expect(
      migration,
      contains(
        'DROP POLICY IF EXISTS "Authenticated users can create chat rooms"',
      ),
    );
    expect(
      migration,
      contains(
        'REVOKE INSERT ON TABLE public.chat_rooms FROM PUBLIC, anon, authenticated',
      ),
    );
    expect(
      migration,
      contains(
        'REVOKE SELECT ON TABLE public.chat_rooms FROM PUBLIC, anon, authenticated',
      ),
    );
    final chatRoomSelectGrant = migration.substring(
      migration.indexOf('GRANT SELECT (\n  id, type, name, description'),
      migration.indexOf(') ON TABLE public.chat_rooms TO authenticated'),
    );
    expect(chatRoomSelectGrant, isNot(contains('last_message')));
    expect(
      migration,
      contains('IF NOT private.user_is_active_internal(p_other_user_id)'),
    );
    expect(migration, contains('FUNCTION public.create_group_chat'));
    expect(chat, contains("'create_group_chat'"));
    final groupCreation = chat.substring(
      chat.indexOf('Future<ChatRoomModel> createGroupChat'),
      chat.indexOf('Future<void> updateLastRead'),
    );
    expect(groupCreation, isNot(contains(".from('chat_rooms').insert")));
    expect(groupCreation, isNot(contains(".from('chat_participants').insert")));
    final lastMessageFunction = migration.substring(
      migration.indexOf('FUNCTION public.update_chat_room_last_message'),
      migration.indexOf(
        'REVOKE ALL ON FUNCTION public.update_chat_room_last_message',
      ),
    );
    expect(lastMessageFunction, contains('SECURITY DEFINER'));
    expect(migration, contains('can_manage_group_participants'));
    expect(migration, isNot(contains('OR auth.uid() = user_id\n  )')));
    expect(migration, contains('direct room participant limit exceeded'));
    expect(
      migration,
      contains('WHERE cp.room_id = r.id AND cp.is_active\n    ) = 2'),
    );
    expect(migration, contains('participant identity and role are immutable'));
    expect(migration, contains('NOT OLD.is_active AND NEW.is_active'));
    expect(migration, contains('chat_participants_update_self_or_manager'));
    expect(
      migration,
      contains('OR private.can_manage_group_participants(room_id, auth.uid())'),
    );
    expect(
      migration,
      contains('participant reactivation requires a group manager'),
    );
    expect(chat, contains("'is_active': true"));
    final addMembers = chat.substring(
      chat.lastIndexOf('Future<void> addChatMembers'),
      chat.lastIndexOf('Future<void> updateChatRoomName'),
    );
    expect(addMembers, isNot(contains("'role': 'member'")));
    expect(addMembers, contains("onConflict: 'room_id,user_id'"));
    expect(
      migration,
      contains(
        'DROP POLICY IF EXISTS "Users can update own participant record"',
      ),
    );
  });

  test('block and interaction inserts share a serialized pair lock', () {
    expect(
      migration,
      contains('FUNCTION private.lock_user_pair_internal(uuid, uuid)'),
    );
    expect(
      migration,
      contains("least(p_user_a::text, p_user_b::text) || ':' ||"),
    );
    for (final trigger in [
      'guard_blocked_follow_insert',
      'guard_blocked_like_insert',
      'guard_blocked_comment_insert',
      'guard_blocked_comment_like_insert',
      'guard_blocked_chat_participant_insert',
      'guard_blocked_chat_message_insert',
    ]) {
      expect(migration, contains('TRIGGER $trigger'));
    }
    expect(
      migration,
      contains('PERFORM private.lock_user_pair_internal(v_actor, v_target)'),
    );
    expect(
      migration,
      contains(
        'PERFORM private.lock_user_pair_internal(v_actor, p_blocked_id)',
      ),
    );
    expect(
      migration,
      contains(
        'PERFORM private.lock_user_pair_internal(v_actor, p_other_user_id)',
      ),
    );
    expect(
      migration,
      contains(
        'PERFORM private.lock_user_pair_internal(p_user_id, p_sender_id)',
      ),
    );
    final interactionGuard = migration.substring(
      migration.indexOf('FUNCTION private.guard_blocked_interaction_insert'),
      migration.indexOf(
        'REVOKE ALL ON FUNCTION private.guard_blocked_interaction_insert',
      ),
    );
    final messageBranch = interactionGuard.substring(
      interactionGuard.indexOf("WHEN 'chat_messages'"),
      interactionGuard.indexOf('ELSE\n      RAISE EXCEPTION'),
    );
    expect(messageBranch, contains("IF v_room_type = 'direct' THEN"));
    expect(messageBranch, contains('END IF;'));
  });

  test('block cache is scoped to the current auth user', () {
    final blockService = File(
      'lib/core/services/block_service.dart',
    ).readAsStringSync();
    expect(blockService, contains('_cachedForUserId'));
    expect(blockService, contains('_cachedForUserId == currentUserId'));
    expect(blockService, contains('_cachedForUserId = null'));
  });

  test('authentication logs and failures do not expose personal data', () {
    expect(auth, isNot(contains('KAKAO_1A_VERIFY')));
    expect(auth, isNot(contains('email: \$kakaoEmail')));
    expect(auth, isNot(contains('nickname:')));
    expect(auth, isNot(contains('NONNULL_uid_')));
    expect(auth, isNot(contains('Profile update error: \$e')));
    expect(auth, contains("GeneralFailure(message: '프로필 업데이트 중 오류가 발생했습니다.')"));
  });

  test('search debounce cannot mix a new query with an old cursor', () {
    expect(privacy, contains('!(_debounce?.isActive ?? false)'));
    final searchChanged = privacy.substring(
      privacy.indexOf('void _onSearchChanged'),
      privacy.indexOf('void _onScroll'),
    );
    expect(searchChanged, contains('_requestToken++'));
  });

  test('user search quotes PostgREST filter values', () {
    final userSource = File(
      'lib/features/social/data/datasources/'
      'social_remote_data_source_impl_user.dart',
    ).readAsStringSync();
    expect(userSource, contains('_quotePostgrestValue'));
    expect(userSource, contains('display_name.ilike.\$searchPattern'));
    expect(userSource, contains("value.replaceAll(r'\\', r'\\\\')"));
  });

  test('blocked users are masked and wildcard search is literal', () {
    final blockedUsers = migration.substring(
      migration.indexOf('FUNCTION public.get_blocked_users'),
      migration.indexOf('REVOKE ALL ON FUNCTION public.get_blocked_user_ids'),
    );
    expect(blockedUsers, contains("'탈퇴한 사용자'::text"));
    expect(blockedUsers, contains('WHEN u.deleted_at IS NULL'));
    expect(
      blockedUsers,
      contains("replace(replace(value, E'\\\\', E'\\\\\\\\')"),
    );
    expect(
      blockedUsers,
      contains("ILIKE '%' || q.escaped || '%' ESCAPE E'\\\\'"),
    );
  });

  test('follow targets must remain active', () {
    final interactionGuard = migration.substring(
      migration.indexOf('FUNCTION private.guard_blocked_interaction_insert'),
      migration.indexOf(
        'REVOKE ALL ON FUNCTION private.guard_blocked_interaction_insert',
      ),
    );
    final followBranch = interactionGuard.substring(
      interactionGuard.indexOf("WHEN 'follows'"),
      interactionGuard.indexOf("WHEN 'likes'"),
    );
    expect(
      followBranch,
      contains('private.user_is_active_internal(NEW.following_id)'),
    );
  });

  test(
    'complete FCM delivery failure is observable without sensitive data',
    () {
      final warning = pushFunction.substring(
        pushFunction.indexOf('if (sent === 0 && failed > 0)'),
        pushFunction.indexOf('if (sent > 0)'),
      );
      expect(warning, contains('All FCM deliveries failed'));
      expect(warning, contains('failed'));
      expect(warning, contains('device_count'));
      expect(warning, isNot(contains('fcm_token')));
      expect(warning, isNot(contains('notification.body')));
      expect(warning, isNot(contains('notification.user_id')));
    },
  );
}
