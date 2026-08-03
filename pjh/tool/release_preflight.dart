import 'dart:io';

enum ReleaseFindingLevel {
  pass,
  warning,
  blocker,
  manual,
}

class ReleaseFinding {
  const ReleaseFinding(this.level, this.code, this.message);

  final ReleaseFindingLevel level;
  final String code;
  final String message;
}

class ReleasePreflight {
  ReleasePreflight(this.appRoot);

  final Directory appRoot;

  Directory get workspaceRoot => appRoot.parent;

  List<ReleaseFinding> run() {
    final findings = <ReleaseFinding>[];

    final pubspec = _read('pubspec.yaml');
    final appConfig = _read('lib/config/app_config.dart');
    final androidGradle = _read('android/app/build.gradle.kts');
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    final infoPlist = _read('ios/Runner/Info.plist');
    final releaseEntitlements = _read('ios/Runner/Runner.entitlements');
    final debugEntitlements = _read('ios/Runner/RunnerDebug.entitlements');
    final privacyManifest = _read('ios/Runner/PrivacyInfo.xcprivacy');
    final podfile = _read('ios/Podfile');
    final postModel = _read('lib/features/social/data/models/post_model.dart');
    final communityEditor = _read(
      'lib/features/feed_hub/presentation/pages/'
      'create_community_post_page.dart',
    );
    final legalDocuments = _read('lib/core/constants/legal_documents.dart');
    final mySettings = _read(
      'lib/features/my/presentation/pages/my_settings_page.dart',
    );
    final settingsBottomSheet = _read(
      'lib/features/my/presentation/widgets/settings_bottom_sheet.dart',
    );
    final onboardingLogin = _read(
      'lib/features/onboarding/presentation/pages/onboarding_login_page.dart',
    );
    final accountDeletion = _readWorkspace(
      'supabase/functions/request-account-deletion/index.ts',
    );
    final accountPurge = _readWorkspace(
      'supabase/functions/purge-deleted-accounts/index.ts',
    );
    final accountPurgeMigration = _readWorkspace(
      'supabase/migrations/L1_account_purge_contract.sql',
    );
    final accountAccessMigration = _readWorkspace(
      'supabase/migrations/L2_account_deletion_access_guard.sql',
    );
    final canonicalDatabase = _readWorkspace('supabase/petspace_setup.sql');
    final authRepository = _read(
      'lib/features/auth/data/repositories/auth_repository_impl.dart',
    );
    final appleDeletionAuthorization = _read(
      'lib/features/auth/data/services/'
      'apple_account_deletion_authorization.dart',
    );

    _checkVersion(findings, pubspec, appConfig);
    _checkAndroidPackage(findings, androidGradle, appConfig);
    _expectContains(
      findings,
      project,
      'PRODUCT_BUNDLE_IDENTIFIER = com.jena.petspace;',
      code: 'IOS_BUNDLE_ID',
      pass: 'iOS bundle ID is com.jena.petspace.',
      failure: 'iOS bundle ID does not match com.jena.petspace.',
    );
    _expectContains(
      findings,
      infoPlist,
      '<string>펫페이스</string>',
      code: 'IOS_DISPLAY_NAME',
      pass: 'iOS display name is configured.',
      failure: 'iOS display name is missing.',
    );
    _expectContains(
      findings,
      releaseEntitlements,
      'com.apple.developer.applesignin',
      code: 'APPLE_SIGN_IN_ENTITLEMENT',
      pass: 'Sign in with Apple entitlement is configured.',
      failure: 'Sign in with Apple entitlement is missing.',
    );
    _expectContains(
      findings,
      releaseEntitlements,
      '<string>production</string>',
      code: 'RELEASE_APNS_ENVIRONMENT',
      pass: 'Release APNs entitlement uses production.',
      failure: 'Release APNs entitlement is not production.',
    );
    _expectContains(
      findings,
      debugEntitlements,
      '<string>development</string>',
      code: 'DEBUG_APNS_ENVIRONMENT',
      pass: 'Debug APNs entitlement uses development.',
      failure: 'Debug APNs entitlement is not development.',
    );
    _expectContains(
      findings,
      infoPlist,
      '<string>remote-notification</string>',
      code: 'REMOTE_NOTIFICATION_MODE',
      pass: 'Remote notification background mode is configured.',
      failure: 'Remote notification background mode is missing.',
    );
    _expectContains(
      findings,
      infoPlist,
      '<key>ITSAppUsesNonExemptEncryption</key>',
      code: 'EXPORT_COMPLIANCE_KEY',
      pass: 'Export-compliance metadata is present.',
      failure: 'Export-compliance metadata is missing.',
    );
    _expectContains(
      findings,
      podfile,
      "platform :ios, '16.0'",
      code: 'IOS_DEPLOYMENT_TARGET',
      pass: 'Podfile deployment target is iOS 16.0.',
      failure: 'Podfile deployment target is not iOS 16.0.',
    );
    _expectContains(
      findings,
      project,
      'TARGETED_DEVICE_FAMILY = "1,2";',
      code: 'IPAD_SUPPORT',
      pass: 'The target currently supports iPhone and iPad.',
      failure: 'The target device-family declaration needs review.',
    );
    _expectContains(
      findings,
      privacyManifest,
      '<key>NSPrivacyTracking</key>\n  <false/>',
      code: 'TRACKING_DECLARATION',
      pass: 'The local privacy manifest declares tracking disabled.',
      failure: 'The local privacy manifest tracking declaration changed.',
    );
    _checkRequiredReasonApis(findings, privacyManifest);
    _checkPreciseLocation(findings, postModel, privacyManifest);
    _checkCommunityContentFilter(findings, communityEditor);
    _checkAppleDeletion(
      findings,
      accountDeletion,
      '$authRepository\n$appleDeletionAuthorization',
    );
    _checkAccountPurge(
      findings,
      accountPurge,
      accountPurgeMigration,
      canonicalDatabase,
    );
    _checkAccountDeletionAccess(
      findings,
      accountDeletion,
      accountAccessMigration,
      canonicalDatabase,
    );
    _checkAccountDeletionDisclosure(
      findings,
      legalDocuments,
      '$mySettings\n$settingsBottomSheet\n$onboardingLogin',
    );
    _checkStoreUrls(findings, appConfig);
    _expectContains(
      findings,
      legalDocuments,
      '펫페이스 개인정보 처리방침',
      code: 'IN_APP_PRIVACY_POLICY',
      pass: 'An in-app privacy policy document is present.',
      failure: 'The in-app privacy policy document is missing.',
    );

    _presenceOnly(
      findings,
      'LOCAL_SECRET_CONFIG',
      File('${appRoot.path}/lib/config/secrets.dart'),
      'Local validation configuration',
    );
    _presenceOnly(
      findings,
      'FIREBASE_IOS_CONFIG',
      File('${appRoot.path}/ios/Runner/GoogleService-Info.plist'),
      'iOS Firebase configuration',
    );

    findings
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'APPLE_REVOKE_RUNTIME',
          'Configure the four Apple revoke secrets, deploy the reviewed Edge '
              'Function, and verify deletion with a real Apple account.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'ACCOUNT_PURGE_RUNTIME',
          'Apply the reviewed account-purge migration, deploy the purge Edge '
              'Function, configure its secret, schedule the daily job, and '
              'alert on failed account or location-audit cleanup.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'PUBLIC_LEGAL_URLS',
          'Verify that privacy, terms, and support URLs are publicly reachable.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'FIREBASE_APNS_KEY',
          'Verify the APNs authentication key in Firebase Console.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'REAL_DEVICE_PUSH',
          'Verify foreground, background, and terminated push on a real device.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'APP_STORE_CONNECT',
          'Complete privacy answers, age rating, review contact, demo account, '
              'screenshots, signing, and submission in App Store Connect.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'THIRD_PARTY_PRIVACY_MANIFESTS',
          'Inspect the signed release archive for third-party SDK privacy '
              'manifests and signatures.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'MARKETING_PUSH_CONSENT',
          'Verify that marketing push consent and withdrawal are separate '
              'from required service notifications.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'APPLE_PRIVATE_RELAY',
          'Verify Apple private-relay sender registration and real-account '
              'email delivery.',
        ),
      )
      ..add(
        const ReleaseFinding(
          ReleaseFindingLevel.manual,
          'IPAD_LAYOUT',
          'Verify rotation, Split View, image picking, dialogs, and required '
              'screenshots on iPad.',
        ),
      );

    return findings;
  }

  String _read(String relativePath) {
    final file = File('${appRoot.path}/$relativePath');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  String _readWorkspace(String relativePath) {
    final file = File('${workspaceRoot.path}/$relativePath');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  void _checkVersion(
    List<ReleaseFinding> findings,
    String pubspec,
    String appConfig,
  ) {
    final pubspecVersion =
        RegExp(r'^version:\s*([0-9.]+)\+([0-9]+)\s*$', multiLine: true)
            .firstMatch(pubspec);
    final configVersion = RegExp(
      r"appVersion\s*=\s*'([^']+)'",
    ).firstMatch(appConfig);
    final configBuild = RegExp(
      r'buildNumber\s*=\s*([0-9]+)',
    ).firstMatch(appConfig);

    if (pubspecVersion == null) {
      findings.add(
        const ReleaseFinding(
          ReleaseFindingLevel.blocker,
          'VERSION_SOURCE',
          'pubspec.yaml has no valid release version.',
        ),
      );
      return;
    }

    final version = pubspecVersion.group(1)!;
    final build = pubspecVersion.group(2)!;
    if (configVersion?.group(1) == version && configBuild?.group(1) == build) {
      findings.add(
        ReleaseFinding(
          ReleaseFindingLevel.pass,
          'VERSION_SOURCE_SYNC',
          'Release version sources agree on $version+$build.',
        ),
      );
      return;
    }

    findings.add(
      ReleaseFinding(
        ReleaseFindingLevel.blocker,
        'VERSION_SOURCE_SYNC',
        'Release version sources disagree; pubspec.yaml is $version+$build.',
      ),
    );
  }

  void _checkAndroidPackage(
    List<ReleaseFinding> findings,
    String androidGradle,
    String appConfig,
  ) {
    final applicationId = RegExp(
      r'applicationId\s*=\s*"([^"]+)"',
    ).firstMatch(androidGradle)?.group(1);
    if (applicationId == null) {
      findings.add(
        const ReleaseFinding(
          ReleaseFindingLevel.blocker,
          'ANDROID_APPLICATION_ID',
          'Android applicationId could not be read.',
        ),
      );
      return;
    }

    final expectedUrl = 'play.google.com/store/apps/details?id=$applicationId';
    findings
      ..add(
        ReleaseFinding(
          ReleaseFindingLevel.pass,
          'ANDROID_APPLICATION_ID',
          'Android applicationId is $applicationId.',
        ),
      )
      ..add(
        ReleaseFinding(
          appConfig.contains(expectedUrl)
              ? ReleaseFindingLevel.pass
              : ReleaseFindingLevel.blocker,
          'PLAY_STORE_PACKAGE_URL',
          appConfig.contains(expectedUrl)
              ? 'The Play Store URL matches the Android applicationId.'
              : 'The Play Store URL does not match Android applicationId '
                  '$applicationId.',
        ),
      );
  }

  void _checkRequiredReasonApis(
    List<ReleaseFinding> findings,
    String privacyManifest,
  ) {
    const requiredEntries = <String>[
      'NSPrivacyAccessedAPICategoryUserDefaults',
      'CA92.1',
      'NSPrivacyAccessedAPICategoryFileTimestamp',
      'C617.1',
      'NSPrivacyAccessedAPICategoryDiskSpace',
      'E174.1',
      'NSPrivacyAccessedAPICategorySystemBootTime',
      '35F9.1',
    ];
    final missing = requiredEntries
        .where((entry) => !privacyManifest.contains(entry))
        .toList();

    findings.add(
      ReleaseFinding(
        missing.isEmpty
            ? ReleaseFindingLevel.pass
            : ReleaseFindingLevel.blocker,
        'REQUIRED_REASON_APIS',
        missing.isEmpty
            ? 'The four reviewed required-reason API categories and reasons '
                'are declared.'
            : 'The local privacy manifest is missing reviewed '
                'required-reason API entries.',
      ),
    );
  }

  void _checkPreciseLocation(
    List<ReleaseFinding> findings,
    String postModel,
    String privacyManifest,
  ) {
    final exactLocationIsPersisted = postModel.contains("'location_lat'") &&
        postModel.contains("'location_lng'");
    final preciseLocationIsDeclared =
        privacyManifest.contains('NSPrivacyCollectedDataTypePreciseLocation');
    final preciseLocationIsLinked = RegExp(
      r'NSPrivacyCollectedDataTypePreciseLocation[\s\S]{0,300}'
      r'NSPrivacyCollectedDataTypeLinked</key>\s*<true/>',
    ).hasMatch(privacyManifest);

    if (exactLocationIsPersisted &&
        (!preciseLocationIsDeclared || !preciseLocationIsLinked)) {
      findings.add(
        const ReleaseFinding(
          ReleaseFindingLevel.blocker,
          'PRECISE_LOCATION_PRIVACY',
          'Exact post coordinates are persisted but linked precise location '
              'is not declared in PrivacyInfo.xcprivacy.',
        ),
      );
      return;
    }

    findings.add(
      const ReleaseFinding(
        ReleaseFindingLevel.pass,
        'PRECISE_LOCATION_PRIVACY',
        'Persisted location fields and the precise-location declaration agree.',
      ),
    );
  }

  void _checkCommunityContentFilter(
    List<ReleaseFinding> findings,
    String communityEditor,
  ) {
    final isFiltered = communityEditor.contains('ContentFilter');
    findings.add(
      ReleaseFinding(
        isFiltered ? ReleaseFindingLevel.pass : ReleaseFindingLevel.blocker,
        'COMMUNITY_CONTENT_FILTER',
        isFiltered
            ? 'Community post creation uses the shared content filter.'
            : 'Community post creation does not use the shared content '
                'filter used by other UGC entry points.',
      ),
    );
  }

  void _checkAppleDeletion(
    List<ReleaseFinding> findings,
    String accountDeletion,
    String authRepository,
  ) {
    const serverRequirements = <String>[
      '/auth/token',
      '/auth/revoke',
      'refresh_token',
      'jwtVerify',
      'APPLE_PRIVATE_KEY',
      'APPLE_CLIENT_ID',
      'expectedSubject',
      'expectedSubject: appleIdentity.id',
    ];
    const clientRequirements = <String>[
      'authorizationCode',
      'appleAuthorizationCode',
      'appleNonce',
      'request-account-deletion',
    ];
    final serverComplete = serverRequirements.every(accountDeletion.contains);
    final clientComplete = clientRequirements.every(authRepository.contains);
    if (!serverComplete || !clientComplete) {
      findings.add(
        const ReleaseFinding(
          ReleaseFindingLevel.blocker,
          'APPLE_TOKEN_REVOCATION',
          'The reviewed client-to-Edge Apple reauthentication, token '
              'verification, and credential-revocation flow is incomplete.',
        ),
      );
      return;
    }

    findings.add(
      const ReleaseFinding(
        ReleaseFindingLevel.pass,
        'APPLE_TOKEN_REVOCATION',
        'The client and Edge function contain the reviewed Apple '
            'reauthentication, identity verification, and refresh-token '
            'revocation flow.',
      ),
    );
  }

  void _checkAccountPurge(
    List<ReleaseFinding> findings,
    String accountPurge,
    String accountPurgeMigration,
    String canonicalDatabase,
  ) {
    const purgeRequirements = <String>[
      'PURGE_SHARED_SECRET',
      'PAGE_SIZE',
      'getUserById',
      'AUTH_USER_DELETE_FAILED',
      'PROFILE_DELETE_UNVERIFIED',
      'STORAGE_DELETE_FAILED',
      'NOTIFICATION_CONTENT_DELETE_FAILED',
      'CHAT_PREVIEW_CLEAR_FAILED',
      'LOCATION_AUDIT_RETENTION_MONTHS',
      'LOCATION_AUDIT_EXPIRY_FAILED',
      '.from("location_access_log")',
      'failureCodes',
    ];
    final purgeIsRetrySafe = purgeRequirements.every(accountPurge.contains);
    final residualCleanupIndex =
        accountPurge.indexOf('await removeResidualSnapshots(admin, id)');
    final authDeleteIndex =
        accountPurge.indexOf('await deleteAuthUserIfPresent(admin, id)');
    final residualCleanupPrecedesIdentityDeletion =
        residualCleanupIndex >= 0 && authDeleteIndex > residualCleanupIndex;
    final canonicalCascade = RegExp(
      r'user_id\s+UUID\s+REFERENCES auth\.users\(id\)'
      r'\s+ON DELETE CASCADE\s+NOT NULL',
    ).hasMatch(canonicalDatabase);
    final migrationIsGuarded = accountPurgeMigration
            .contains("to_regclass('public.health_history')") &&
        accountPurgeMigration.contains('ON DELETE CASCADE');

    final complete = purgeIsRetrySafe &&
        residualCleanupPrecedesIdentityDeletion &&
        canonicalCascade &&
        migrationIsGuarded;
    findings.add(
      ReleaseFinding(
        complete ? ReleaseFindingLevel.pass : ReleaseFindingLevel.blocker,
        'ACCOUNT_PURGE_CONTRACT',
        complete
            ? 'The 30-day purge is paginated, retry-safe, storage-aware, and '
                'removes notification/chat snapshots before identity deletion.'
            : 'The 30-day account-purge implementation or its health-history '
                'foreign-key contract is incomplete.',
      ),
    );
  }

  void _checkAccountDeletionAccess(
    List<ReleaseFinding> findings,
    String accountDeletion,
    String accountAccessMigration,
    String canonicalDatabase,
  ) {
    final softDeleteIndex = accountDeletion.indexOf('.update({ deleted_at:');
    final globalSignOutIndex =
        accountDeletion.indexOf('admin.auth.admin.signOut');
    final deletionPrecedesSessionCleanup =
        softDeleteIndex >= 0 && globalSignOutIndex > softDeleteIndex;
    const guardRequirements = <String>[
      'AS RESTRICTIVE FOR ALL TO authenticated',
      'private.user_is_active_internal(auth.uid())',
      "'health_history'",
      "'chat_messages'",
      "'posts'",
    ];
    final migrationComplete =
        guardRequirements.every(accountAccessMigration.contains);
    final canonicalComplete =
        guardRequirements.every(canonicalDatabase.contains);

    final complete = deletionPrecedesSessionCleanup &&
        migrationComplete &&
        canonicalComplete;
    findings.add(
      ReleaseFinding(
        complete ? ReleaseFindingLevel.pass : ReleaseFindingLevel.blocker,
        'SOFT_DELETE_ACCESS_GUARD',
        complete
            ? 'Apple revocation is followed by soft delete before best-effort '
                'session cleanup, and restrictive RLS blocks remaining access '
                'tokens from user-owned data.'
            : 'The soft-delete order or restrictive active-account RLS guard '
                'is incomplete.',
      ),
    );
  }

  void _checkAccountDeletionDisclosure(
    List<ReleaseFinding> findings,
    String legalDocuments,
    String deletionSurfaces,
  ) {
    final policyDisclosesRetention = legalDocuments.contains(
      '해당 자료는 6개월간 보관합니다.',
    );
    final settingsDiscloseException = deletionSurfaces.contains(
      '법령상 보관 의무가 있는 자료',
    );
    final recoveryDisclosesException = deletionSurfaces.contains(
      '법령상 보존 자료',
    );
    final hasNoBlanketDeletionClaim = !deletionSurfaces.contains(
      '모든 데이터가 영구 삭제',
    );
    final complete = policyDisclosesRetention &&
        settingsDiscloseException &&
        recoveryDisclosesException &&
        hasNoBlanketDeletionClaim;

    findings.add(
      ReleaseFinding(
        complete ? ReleaseFindingLevel.pass : ReleaseFindingLevel.blocker,
        'ACCOUNT_DELETION_DISCLOSURE',
        complete
            ? 'Deletion and recovery surfaces disclose the statutory '
                'six-month location-audit retention exception.'
            : 'Account-deletion copy conflicts with the statutory retention '
                'exception or makes an unconditional deletion promise.',
      ),
    );
  }

  void _checkStoreUrls(
    List<ReleaseFinding> findings,
    String appConfig,
  ) {
    if (RegExp(r'apps\.apple\.com/.+?/id[0-9]+').hasMatch(appConfig)) {
      findings.add(
        const ReleaseFinding(
          ReleaseFindingLevel.pass,
          'APP_STORE_URL',
          'The App Store URL contains a numeric app ID.',
        ),
      );
    } else {
      findings.add(
        const ReleaseFinding(
          ReleaseFindingLevel.warning,
          'APP_STORE_URL',
          'The App Store URL is provisional until App Store Connect assigns '
              'a numeric app ID.',
        ),
      );
    }
  }

  void _presenceOnly(
    List<ReleaseFinding> findings,
    String code,
    File file,
    String label,
  ) {
    findings.add(
      ReleaseFinding(
        file.existsSync()
            ? ReleaseFindingLevel.pass
            : ReleaseFindingLevel.warning,
        code,
        '$label: ${file.existsSync() ? 'present' : 'absent'} '
        '(content not inspected).',
      ),
    );
  }

  void _expectContains(
    List<ReleaseFinding> findings,
    String contents,
    String expected, {
    required String code,
    required String pass,
    required String failure,
  }) {
    findings.add(
      ReleaseFinding(
        contents.contains(expected)
            ? ReleaseFindingLevel.pass
            : ReleaseFindingLevel.blocker,
        code,
        contents.contains(expected) ? pass : failure,
      ),
    );
  }
}

String renderReleasePreflight(List<ReleaseFinding> findings) {
  final buffer = StringBuffer('PetSpace release preflight\n');
  for (final finding in findings) {
    buffer.writeln(
      '[${finding.level.name.toUpperCase()}] '
      '${finding.code}: ${finding.message}',
    );
  }
  final blockers =
      findings.where((finding) => finding.level == ReleaseFindingLevel.blocker);
  buffer.writeln('BLOCKERS=${blockers.length}');
  return buffer.toString();
}

void main(List<String> arguments) {
  var root = Directory.current;
  for (final argument in arguments) {
    if (argument.startsWith('--root=')) {
      root = Directory(argument.substring('--root='.length));
    }
  }

  final findings = ReleasePreflight(root.absolute).run();
  stdout.write(renderReleasePreflight(findings));
  if (findings.any(
    (finding) => finding.level == ReleaseFindingLevel.blocker,
  )) {
    exitCode = 1;
  }
}
