/// 상대시간 표기 공통 유틸 — 피드·라운지 카드 공용.
///
/// 방금 전 / N분 전 / N시간 전 / N일 전, 7일 초과 시 'YYYY년 M/DD'.
String formatRelativeTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays <= 7) return '${diff.inDays}일 전';
  final dd = local.day.toString().padLeft(2, '0');
  return '${local.year}년 ${local.month}/$dd';
}
