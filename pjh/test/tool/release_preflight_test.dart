import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/release_preflight.dart';

void main() {
  test('complete fixture has no blocker', () async {
    final fixture = await _createFixture();
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings.where((finding) => finding.level == ReleaseFindingLevel.blocker),
      isEmpty,
    );
  });

  test('precise coordinates require a precise-location declaration', () async {
    final fixture = await _createFixture(includePreciseLocation: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having(
              (finding) => finding.code,
              'code',
              'PRECISE_LOCATION_PRIVACY',
            )
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('Apple token-revocation handoff marker is a blocker', () async {
    final fixture = await _createFixture(appleRevocationImplemented: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having((finding) => finding.code, 'code', 'APPLE_TOKEN_REVOCATION')
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('account purge requires retry and foreign-key protections', () async {
    final fixture = await _createFixture(accountPurgeProtected: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having((finding) => finding.code, 'code', 'ACCOUNT_PURGE_CONTRACT')
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('soft delete requires an active-account access guard', () async {
    final fixture = await _createFixture(softDeleteAccessProtected: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having(
              (finding) => finding.code,
              'code',
              'SOFT_DELETE_ACCESS_GUARD',
            )
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('account deletion copy must disclose statutory retention', () async {
    final fixture = await _createFixture(
      accountDeletionDisclosureAccurate: false,
    );
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having(
              (finding) => finding.code,
              'code',
              'ACCOUNT_DELETION_DISCLOSURE',
            )
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('Play Store URL must match the actual Android applicationId', () async {
    final fixture = await _createFixture(playPackageMatches: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having((finding) => finding.code, 'code', 'PLAY_STORE_PACKAGE_URL')
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('Android release signing must fail closed', () async {
    final fixture = await _createFixture(androidReleaseProtected: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having(
              (finding) => finding.code,
              'code',
              'ANDROID_RELEASE_SIGNING',
            )
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('Kakao client-derived password remains a release blocker', () async {
    final fixture = await _createFixture(kakaoOidcProtected: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having((finding) => finding.code, 'code', 'KAKAO_AUTH_CONTRACT')
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('Gemini client and proxy request budgets must stay aligned', () async {
    final fixture = await _createFixture(geminiClientRequestMiB: 13);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having((finding) => finding.code, 'code', 'GEMINI_PROXY_CONTRACT')
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('Gemini proxy must retain image and response-format guards', () async {
    final fixture = await _createFixture(geminiProxyProtected: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having((finding) => finding.code, 'code', 'GEMINI_PROXY_CONTRACT')
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('retired legacy analyze-emotion tombstone passes', () async {
    final fixture = await _createFixture();
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings
          .firstWhere(
            (finding) => finding.code == 'LEGACY_ANALYZE_EDGE_CONTRACT',
          )
          .level,
      ReleaseFindingLevel.pass,
    );
  });

  test('legacy analyze-emotion service-role write path is a blocker', () async {
    final fixture = await _createFixture(legacyEmotionSource: 'unsafe');
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings
          .firstWhere(
            (finding) => finding.code == 'LEGACY_ANALYZE_EDGE_CONTRACT',
          )
          .level,
      ReleaseFindingLevel.blocker,
    );
  });

  test('deleting legacy analyze-emotion source remains a blocker', () async {
    final fixture = await _createFixture(legacyEmotionSource: 'absent');
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings
          .firstWhere(
            (finding) => finding.code == 'LEGACY_ANALYZE_EDGE_CONTRACT',
          )
          .level,
      ReleaseFindingLevel.blocker,
    );
  });

  test('legacy analyze-emotion runtime confirmation is always manual',
      () async {
    final fixture = await _createFixture();
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings
          .firstWhere(
            (finding) => finding.code == 'LEGACY_ANALYZE_EDGE_RUNTIME',
          )
          .level,
      ReleaseFindingLevel.manual,
    );
    expect(renderReleasePreflight(findings), contains('MANUAL='));
  });

  test('Windows CRLF does not change text contract checks', () async {
    final fixture = await _createFixture();
    addTearDown(() => fixture.delete(recursive: true));
    final privacyManifest = File(
      p.join(fixture.path, 'pjh/ios/Runner/PrivacyInfo.xcprivacy'),
    );
    privacyManifest.writeAsStringSync(
      privacyManifest.readAsStringSync().replaceAll('\n', '\r\n'),
    );

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings
          .firstWhere((finding) => finding.code == 'TRACKING_DECLARATION')
          .level,
      ReleaseFindingLevel.pass,
    );
  });

  test('community post creation requires the shared content filter', () async {
    final fixture = await _createFixture(includeCommunityFilter: false);
    addTearDown(() => fixture.delete(recursive: true));

    final findings = ReleasePreflight(
      Directory(p.join(fixture.path, 'pjh')),
    ).run();

    expect(
      findings,
      contains(
        isA<ReleaseFinding>()
            .having(
              (finding) => finding.code,
              'code',
              'COMMUNITY_CONTENT_FILTER',
            )
            .having(
              (finding) => finding.level,
              'level',
              ReleaseFindingLevel.blocker,
            ),
      ),
    );
  });

  test('sensitive configuration is presence-only', () async {
    final fixture = await _createFixture();
    addTearDown(() => fixture.delete(recursive: true));
    final appRoot = Directory(p.join(fixture.path, 'pjh'));
    File(p.join(appRoot.path, 'lib/config/secrets.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('NEVER_PRINT_LOCAL_SECRET_VALUE');
    File(p.join(appRoot.path, 'ios/Runner/GoogleService-Info.plist'))
      ..createSync(recursive: true)
      ..writeAsStringSync('NEVER_PRINT_FIREBASE_CONFIG_VALUE');

    final report = renderReleasePreflight(ReleasePreflight(appRoot).run());

    expect(report, contains('LOCAL_SECRET_CONFIG'));
    expect(report, contains('FIREBASE_IOS_CONFIG'));
    expect(report, isNot(contains('NEVER_PRINT_LOCAL_SECRET_VALUE')));
    expect(report, isNot(contains('NEVER_PRINT_FIREBASE_CONFIG_VALUE')));
  });
}

Future<Directory> _createFixture({
  bool includePreciseLocation = true,
  bool appleRevocationImplemented = true,
  bool includeCommunityFilter = true,
  bool playPackageMatches = true,
  bool accountPurgeProtected = true,
  bool softDeleteAccessProtected = true,
  bool accountDeletionDisclosureAccurate = true,
  bool androidReleaseProtected = true,
  bool kakaoOidcProtected = true,
  bool geminiProxyProtected = true,
  String legacyEmotionSource = 'tombstone',
  int geminiClientRequestMiB = 11,
  int geminiProxyRequestMiB = 12,
}) async {
  final workspace = await Directory.systemTemp.createTemp(
    'release-preflight-test-',
  );
  final appRoot = Directory(p.join(workspace.path, 'pjh'));

  void writeApp(String path, String contents) {
    final file = File(p.join(appRoot.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  void writeWorkspace(String path, String contents) {
    final file = File(p.join(workspace.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  writeApp('pubspec.yaml', 'version: 1.0.0+4\n');
  writeApp(
    'lib/config/app_config.dart',
    "static const String appVersion = '1.0.0';\n"
        'static const int buildNumber = 4;\n'
        "const appStoreUrl = 'https://apps.apple.com/app/id1234567890';\n"
        "const playStoreUrl = "
        "'https://play.google.com/store/apps/details?id="
        "${playPackageMatches ? 'com.jena.petspace' : 'com.wrong.package'}';\n",
  );
  writeApp(
    'android/app/build.gradle.kts',
    androidReleaseProtected
        ? 'defaultConfig { applicationId = "com.jena.petspace"; '
            'targetSdk = 36 }\n'
            'val releaseSigningReady = true\n'
            'throw GradleException("Release signing is not configured")\n'
            'buildTypes { release { signingConfig = '
            'signingConfigs.getByName("release") } }\n'
        : 'defaultConfig { applicationId = "com.jena.petspace"; '
            'targetSdk = 36 }\n'
            'buildTypes { release { signingConfig = '
            'signingConfigs.getByName("debug") } }\n',
  );
  writeApp(
    'android/app/src/main/AndroidManifest.xml',
    '<uses-permission android:name="android.permission.INTERNET" />\n'
        '<uses-permission '
        'android:name="android.permission.POST_NOTIFICATIONS" />\n'
        '<intent-filter android:autoVerify="true">\n'
        '<data android:host="petspace.app" />\n'
        '</intent-filter>\n',
  );
  writeApp(
    'lib/core/services/fcm_service.dart',
    "@pragma('vm:entry-point')\n"
        'getInitialMessage(); onMessageOpenedApp;\n',
  );
  writeApp('lib/core/services/notification_service.dart', 'onTokenRefresh;\n');
  writeApp(
    'lib/features/emotion/data/services/gemini_ai_service.dart',
    'functions/v1/gemini-proxy currentSession accessToken '
        'maxImagesPerRequest = 5 '
        'maxSourceImageBytes = 5 * 1024 * 1024 '
        'maxClientRequestBytes = $geminiClientRequestMiB * 1024 * 1024 '
        'maxImageBase64Chars isWithinRequestBudget '
        'isEncodedRequestWithinBudget statusCode == 413\n',
  );
  writeWorkspace(
    'supabase/functions/gemini-proxy/index.ts',
    geminiProxyProtected
        ? 'auth.getUser(jwt) '
            'MAX_REQUEST_BYTES = $geminiProxyRequestMiB * 1024 * 1024 '
            'normalizeRequest '
            'MAX_OUTPUT_TOKENS MAX_IMAGE_PARTS ALLOWED_MIME_TYPES '
            'SAFETY_SETTINGS responseMimeType '
            '분석 요청을 처리하지 못했습니다.\n'
        : 'auth.getUser(jwt) '
            'MAX_REQUEST_BYTES = $geminiProxyRequestMiB * 1024 * 1024 '
            'normalizeRequest '
            'MAX_OUTPUT_TOKENS ALLOWED_MIME_TYPES SAFETY_SETTINGS '
            '분석 요청을 처리하지 못했습니다.\n',
  );
  if (legacyEmotionSource != 'absent') {
    writeWorkspace(
      'supabase/functions/analyze-emotion/index.ts',
      legacyEmotionSource == 'tombstone'
          ? 'auth.getUser(jwt); jsonResponse(410); '
              'LEGACY_ENDPOINT_RETIRED;\n'
          : 'SUPABASE_SERVICE_ROLE_KEY; req.json(); userId; '
              '.storage; .from(); Math.random();\n',
    );
  }
  writeApp(
    'ios/Runner.xcodeproj/project.pbxproj',
    'PRODUCT_BUNDLE_IDENTIFIER = com.jena.petspace;\n'
        'TARGETED_DEVICE_FAMILY = "1,2";\n',
  );
  writeApp(
    'ios/Runner/Info.plist',
    '<string>펫페이스</string>\n'
        '<string>remote-notification</string>\n'
        '<key>ITSAppUsesNonExemptEncryption</key>\n',
  );
  writeApp(
    'ios/Runner/Runner.entitlements',
    'com.apple.developer.applesignin\n<string>production</string>\n',
  );
  writeApp(
    'ios/Runner/RunnerDebug.entitlements',
    '<string>development</string>\n',
  );
  writeApp(
    'ios/Runner/PrivacyInfo.xcprivacy',
    '<key>NSPrivacyTracking</key>\n  <false/>\n'
        '${includePreciseLocation ? 'NSPrivacyCollectedDataTypePreciseLocation</string>\n'
            '<key>NSPrivacyCollectedDataTypeLinked</key>\n<true/>' : ''}\n'
        'NSPrivacyAccessedAPICategoryUserDefaults\n'
        'CA92.1\n'
        'NSPrivacyAccessedAPICategoryFileTimestamp\n'
        'C617.1\n'
        'NSPrivacyAccessedAPICategoryDiskSpace\n'
        'E174.1\n'
        'NSPrivacyAccessedAPICategorySystemBootTime\n'
        '35F9.1\n',
  );
  writeApp('ios/Podfile', "platform :ios, '16.0'\n");
  writeApp(
    'lib/features/social/data/models/post_model.dart',
    "const fields = ['location_lat', 'location_lng'];\n",
  );
  writeApp(
    'lib/core/constants/legal_documents.dart',
    '펫페이스 개인정보 처리방침\n'
        '${accountDeletionDisclosureAccurate ? '해당 자료는 6개월간 보관합니다.\n' : ''}',
  );
  final deletionCopy = accountDeletionDisclosureAccurate
      ? '계정과 서비스 데이터가 영구 삭제됩니다. '
          '법령상 보관 의무가 있는 자료는 분리 보관됩니다. '
          '법령상 보존 자료는 정해진 기간 동안 분리 보관돼요.\n'
      : '모든 데이터가 영구 삭제됩니다.\n';
  writeApp(
    'lib/features/my/presentation/pages/my_settings_page.dart',
    deletionCopy,
  );
  writeApp(
    'lib/features/my/presentation/widgets/settings_bottom_sheet.dart',
    deletionCopy,
  );
  writeApp(
    'lib/features/onboarding/presentation/pages/onboarding_login_page.dart',
    deletionCopy,
  );
  writeApp(
    'lib/features/feed_hub/presentation/pages/'
    'create_community_post_page.dart',
    includeCommunityFilter
        ? 'final filter = ContentFilter();\n'
        : 'void createCommunityPost() {}\n',
  );
  writeWorkspace(
    'supabase/functions/request-account-deletion/index.ts',
    appleRevocationImplemented
        ? "const token = 'https://appleid.apple.com/auth/token';\n"
            "const revoke = 'https://appleid.apple.com/auth/revoke';\n"
            'const refresh_token = true;\n'
            'jwtVerify(); APPLE_PRIVATE_KEY; APPLE_CLIENT_ID;\n'
            'expectedSubject; expectedSubject: appleIdentity.id;\n'
            '${softDeleteAccessProtected ? ".update({ deleted_at: true }); "
                "admin.auth.admin.signOut();\n" : "admin.auth.admin.signOut(); "
                ".update({ deleted_at: true });\n"}'
        : '// Apple token revoke 미구현\n',
  );
  writeWorkspace(
    'supabase/functions/purge-deleted-accounts/index.ts',
    accountPurgeProtected
        ? 'PURGE_SHARED_SECRET PAGE_SIZE getUserById '
            'await removeResidualSnapshots(admin, id); '
            'await deleteAuthUserIfPresent(admin, id); '
            'AUTH_USER_DELETE_FAILED PROFILE_DELETE_UNVERIFIED '
            'STORAGE_DELETE_FAILED NOTIFICATION_CONTENT_DELETE_FAILED '
            'CHAT_PREVIEW_CLEAR_FAILED LOCATION_AUDIT_RETENTION_MONTHS '
            'LOCATION_AUDIT_EXPIRY_FAILED .from("location_access_log") '
            'failureCodes\n'
        : '// account purge protections missing\n',
  );
  writeWorkspace(
    'supabase/manual_sql/history/L1_account_purge_contract.sql',
    accountPurgeProtected
        ? "to_regclass('public.health_history') ON DELETE CASCADE\n"
        : 'ALTER TABLE public.health_history;\n',
  );
  writeWorkspace(
    'supabase/manual_sql/history/L2_account_deletion_access_guard.sql',
    softDeleteAccessProtected
        ? 'AS RESTRICTIVE FOR ALL TO authenticated '
            'private.user_is_active_internal(auth.uid()) '
            "'health_history' 'chat_messages' 'posts'\n"
        : '// active-account access guard missing\n',
  );
  writeWorkspace(
    'supabase/petspace_setup.sql',
    '${accountPurgeProtected ? 'user_id UUID REFERENCES auth.users(id) '
            'ON DELETE CASCADE NOT NULL\n' : 'user_id UUID REFERENCES '
            'auth.users(id) NOT NULL\n'}'
        '${softDeleteAccessProtected ? 'AS RESTRICTIVE FOR ALL TO authenticated '
            'private.user_is_active_internal(auth.uid()) '
            "'health_history' 'chat_messages' 'posts'\n" : ''}'
        '${kakaoOidcProtected ? '' : 'CREATE OR REPLACE FUNCTION '
            'confirm_kakao_user_by_email(p_email text);\n'}',
  );
  writeApp(
    'lib/features/auth/data/repositories/auth_repository_impl.dart',
    '${appleRevocationImplemented ? 'authorizationCode; '
            'appleAuthorizationCode; appleNonce; '
            'request-account-deletion;\n' : 'request-account-deletion;\n'}'
        '${kakaoOidcProtected ? 'OAuthProvider.kakao; signInWithIdToken;\n' : 'kakaoPasswordSalt; confirm_kakao_user_by_email;\n'}',
  );
  return workspace;
}
