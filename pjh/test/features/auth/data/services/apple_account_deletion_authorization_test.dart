import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/auth/data/services/apple_account_deletion_authorization.dart';

void main() {
  group('AppleAccountDeletionPolicy', () {
    test('Apple identity is detected without accepting partial provider names',
        () {
      expect(
        AppleAccountDeletionPolicy.hasAppleIdentity(
          const ['email', 'apple', 'google'],
        ),
        isTrue,
      );
      expect(
        AppleAccountDeletionPolicy.hasAppleIdentity(
          const ['email', 'apple-enterprise'],
        ),
        isFalse,
      );
    });

    test('nonce hashing is deterministic SHA-256', () {
      expect(
        AppleAccountDeletionPolicy.hashNonce('petspace-test-nonce'),
        '47dcfe2b174ab8778ae4c5d9ab5a18ba3f83a2d15d1d04a574ee368032e80b05',
      );
    });
  });

  test('request body uses only the approved ephemeral fields', () {
    const authorization = AppleAccountDeletionAuthorization(
      authorizationCode: 'temporary-code',
      rawNonce: 'temporary-nonce',
    );

    expect(
      authorization.toRequestBody(),
      {
        'appleAuthorizationCode': 'temporary-code',
        'appleNonce': 'temporary-nonce',
      },
    );
  });
}
