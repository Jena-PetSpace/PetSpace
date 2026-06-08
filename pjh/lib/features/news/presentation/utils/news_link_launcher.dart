import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 기사 원문으로 링크아웃. 본문을 복제·표시하지 않고 원문으로 이동(저작권 원칙).
/// 1차: 인앱 브라우저 뷰(앱 안에서 열리되 상단에 출처·원문 맥락 유지),
/// 실패 시 외부 브라우저로 폴백. 둘 다 실패하면 스낵바 안내.
Future<void> openArticle(BuildContext context, String link) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(link);
  if (uri == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('기사 주소가 올바르지 않아요.')),
    );
    return;
  }

  try {
    // 인앱 브라우저 뷰(iOS SFSafariViewController / Android Custom Tabs).
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (ok) return;
  } catch (_) {
    // 아래 외부 브라우저 폴백으로 진행
  }

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) return;
  } catch (_) {}

  messenger.showSnackBar(
    const SnackBar(content: Text('기사를 열 수 없어요. 잠시 후 다시 시도해주세요.')),
  );
}
