import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('B0 diff는 Home/AI/Apple/iOS 보호 경로를 변경하지 않는다', () async {
    const protectedPaths = [
      'pjh/lib/features/home/presentation',
      'pjh/lib/features/emotion/presentation',
      'pjh/lib/features/auth/data/repositories/auth_repository_impl.dart',
      'pjh/lib/core/utils/share_origin.dart',
      'pjh/ios/Runner/Info.plist',
      'pjh/ios/Runner/Runner.entitlements',
      'pjh/ios/Runner.xcodeproj/project.pbxproj',
      'pjh/lib/firebase_options.dart',
    ];
    final result = await Process.run(
      'git',
      ['diff', '--name-only', 'HEAD', '--', ...protectedPaths],
      workingDirectory: '..',
    );
    expect(result.exitCode, 0);
    expect((result.stdout as String).trim(), isEmpty);
  });

  test('현재 수동 변경은 B0 manifest 또는 기존 사용자 소유 경로뿐이다', () async {
    const allowedPrefixes = [
      '.agents/',
      '.codex/agents/',
    ];
    const allowedPaths = {
      '.codex/config.toml',
      'AGENTS.md',
      'docs/work-orders/2026-08-04-b0-safety-foundation.md',
      'pjh/android/app/build.gradle.kts',
      'pjh/lib/core/error/error_messages.dart',
      'pjh/lib/core/services/fcm_service.dart',
      'pjh/lib/core/services/realtime_service.dart',
      'pjh/lib/features/mbti/presentation/bloc/mbti_test_bloc.dart',
      'pjh/lib/features/mbti/presentation/widgets/my_mbti_badge_section.dart',
      'pjh/lib/features/news/presentation/pages/news_list_page.dart',
      'pjh/lib/features/pets/presentation/pages/pet_detail_page.dart',
      'pjh/lib/features/pets/presentation/pages/pet_editor_page.dart',
      'pjh/lib/features/pets/presentation/pages/pet_management_page.dart',
      'pjh/lib/features/social/presentation/pages/comments_page.dart',
      'pjh/lib/features/social/presentation/pages/post_detail_page.dart',
      'pjh/lib/features/social/presentation/bloc/bookmark_bloc.dart',
      'pjh/lib/features/social/presentation/widgets/comments_bottom_sheet.dart',
      'pjh/lib/main_navigation.dart',
      'pjh/lib/shared/themes/app_theme.dart',
      'pjh/lib/shared/widgets/error_dialog.dart',
      'pjh/lib/shared/widgets/lazy_load_list.dart',
      'pjh/test/contracts/b0_protected_paths_contract_test.dart',
      'pjh/test/contracts/b0_release_safety_contract_test.dart',
      'pjh/test/contracts/b0_uiux_inventory_contract_test.dart',
      'pjh/test/contracts/b0_visibility_fail_closed_contract_test.dart',
      'pjh/test/contracts/p2b_block_privacy_contract_test.dart',
      'pjh/test/contracts/public_error_message_contract_test.dart',
      'pjh/test/contracts/uiux_scope_boundary_contract_test.dart',
      'pjh/test/main_navigation_test.dart',
      'pjh/test/shared/themes/app_theme_test.dart',
      'pjh/tool/uiux_frozen_scope.sha256',
      'pjh/tool/uiux_protected_scope.sha256',
      'supabase/migrations/20260804_b0_post_visibility_fail_closed.sql',
      'supabase/petspace_setup.sql',
    };
    final result = await Process.run(
      'git',
      ['status', '--porcelain', '--untracked-files=normal'],
      workingDirectory: '..',
    );
    expect(result.exitCode, 0);
    final unexpected = (result.stdout as String)
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.length > 3 ? line.substring(3).trim() : line.trim())
        .where((path) =>
            !allowedPaths.contains(path) &&
            !allowedPrefixes.any(path.startsWith))
        .toList();
    expect(unexpected, isEmpty);
  });
}
