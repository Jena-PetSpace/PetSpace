/// 계정 soft delete 30일 유예 정책 (서버 purge 배치와 동일 기준).
class AccountDeletionPolicy {
  const AccountDeletionPolicy._();

  static const int gracePeriodDays = 30;

  static DateTime purgeAt(DateTime deletedAt) =>
      deletedAt.add(const Duration(days: gracePeriodDays));

  /// 영구 삭제까지 남은 일수 (올림, 최소 0).
  static int remainingDays(DateTime deletedAt, DateTime now) {
    final remaining = purgeAt(deletedAt).difference(now);
    if (remaining.isNegative || remaining == Duration.zero) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }
}
