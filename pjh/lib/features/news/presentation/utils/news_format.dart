import 'package:intl/intl.dart';

/// 뉴스 발행일 표기. 최근은 상대시간, 오래되면 'M월 d일'(올해)·'yyyy.M.d'(작년 이전).
/// publishedAt 이 null 이면 빈 문자열(호출부에서 출처만 표기).
String formatNewsDate(DateTime? publishedAt) {
  if (publishedAt == null) return '';
  final now = DateTime.now();
  final local = publishedAt.toLocal();
  final diff = now.difference(local);

  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  if (local.year == now.year) return DateFormat('M월 d일').format(local);
  return DateFormat('yyyy.M.d').format(local);
}
