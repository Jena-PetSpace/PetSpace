import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BackPressHandler {
  BackPressHandler._();

  // ── 앱 종료 다이얼로그 ─────────────────────────────────────────────────────
  static Future<bool> showExitDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '앱 종료',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'PetSpace를 종료할까요?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          // 취소 — 기본 포커스 (실수 방지)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.primary,
            ),
            child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          // 종료
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── 작성 취소 다이얼로그 ──────────────────────────────────────────────────
  static Future<bool> showDiscardDialog(
    BuildContext context, {
    String title = '작성 취소',
    String content = '작성 중인 내용이 있습니다.\n돌아가면 내용이 사라집니다.',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(content, style: const TextStyle(fontSize: 14)),
        actions: [
          // 계속 작성 — 기본 포커스 (실수 방지)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.primary,
            ),
            child: const Text('계속 작성', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          // 버리기
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('버리기'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── 앱 종료 실행 ──────────────────────────────────────────────────────────
  static void exitApp() => SystemNavigator.pop();
}
