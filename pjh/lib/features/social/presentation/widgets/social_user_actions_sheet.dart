import 'package:flutter/material.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/repositories/social_repository.dart';
import 'social_content_report_sheet.dart';

enum SocialUserAction { report, block }

/// 타 사용자에 대한 신고·차단 진입점과 차단 확인 문구를 한 곳에 고정한다.
abstract final class SocialUserActionsSheet {
  static Future<bool> show(
    BuildContext context, {
    required String targetUserId,
    required String targetUserName,
    required String currentUserId,
    required SocialRepository repository,
    VoidCallback? onBlocked,
  }) async {
    if (targetUserId.isEmpty ||
        currentUserId.isEmpty ||
        targetUserId == currentUserId) {
      return false;
    }

    final action = await showModalBottomSheet<SocialUserAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('social_user_report_action'),
                  isThreeLine: true,
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('사용자 신고'),
                  subtitle: const Text('이 사용자의 계정 활동을 운영팀에 신고합니다.'),
                  onTap: () =>
                      Navigator.pop(sheetContext, SocialUserAction.report),
                ),
                ListTile(
                  key: const Key('social_user_block_action'),
                  isThreeLine: true,
                  leading: const Icon(
                    Icons.block_outlined,
                    color: AppTheme.errorColor,
                  ),
                  title: const Text(
                    '사용자 차단',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                  subtitle: const Text(
                    '서로의 콘텐츠와 활동을 숨기고 상호작용을 제한합니다.',
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, SocialUserAction.block),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return false;

    if (action == SocialUserAction.report) {
      final accepted = await SocialContentReportSheet.show(
        context,
        target: SocialReportTarget.user,
        targetId: targetUserId,
        currentUserId: currentUserId,
        repository: repository,
      );
      if (accepted && context.mounted) {
        _showMessage(context, '사용자 신고가 접수되었습니다.');
      }
      return false;
    }

    final blocked = await confirmBlock(
      context,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
      repository: repository,
    );
    if (blocked) onBlocked?.call();
    return blocked;
  }

  static Future<bool> confirmBlock(
    BuildContext context, {
    required String targetUserId,
    required String targetUserName,
    required SocialRepository repository,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$targetUserName님을 차단할까요?'),
        content: const Text(
          '서로의 게시물·댓글·프로필이 노출되지 않습니다.\n'
          '팔로우·좋아요·답글·신규 채팅 등 상호작용도 제한됩니다.\n\n'
          '개인정보 보호 설정에서 언제든 해제할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('social_user_block_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('차단'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final result = await repository.blockUser(targetUserId);
    if (!context.mounted) return result.isRight();
    return result.fold(
      (_) {
        _showMessage(context, '사용자를 차단하지 못했어요. 잠시 후 다시 시도해주세요.');
        return false;
      },
      (_) {
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('$targetUserName님을 차단했습니다.'),
              action: SnackBarAction(
                label: '차단 해제',
                onPressed: () async {
                  final undoResult = await repository.unblockUser(targetUserId);
                  if (!context.mounted) return;
                  _showMessage(
                    context,
                    undoResult.isRight()
                        ? '$targetUserName님의 차단이 해제되었습니다.'
                        : '차단 해제에 실패했습니다.',
                  );
                },
              ),
            ),
          );
        return true;
      },
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }
}
