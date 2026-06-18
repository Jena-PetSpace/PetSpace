import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/auth/domain/services/account_deletion_policy.dart';

void main() {
  group('AccountDeletionPolicy', () {
    final deletedAt = DateTime(2026, 6, 1, 12, 0);

    test('삭제 직후 잔여일은 30일', () {
      expect(AccountDeletionPolicy.remainingDays(deletedAt, deletedAt), 30);
    });

    test('29.5일 경과 시 잔여일은 1일 (올림)', () {
      final now = deletedAt.add(const Duration(days: 29, hours: 12));
      expect(AccountDeletionPolicy.remainingDays(deletedAt, now), 1);
    });

    test('정확히 30일 경과 시 0일', () {
      final now = deletedAt.add(const Duration(days: 30));
      expect(AccountDeletionPolicy.remainingDays(deletedAt, now), 0);
    });

    test('30일 초과 경과 시 음수 아닌 0', () {
      final now = deletedAt.add(const Duration(days: 31));
      expect(AccountDeletionPolicy.remainingDays(deletedAt, now), 0);
    });

    test('purgeAt은 deletedAt + 30일', () {
      expect(AccountDeletionPolicy.purgeAt(deletedAt), DateTime(2026, 7, 1, 12, 0));
    });
  });
}
