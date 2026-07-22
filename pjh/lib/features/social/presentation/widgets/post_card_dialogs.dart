part of 'post_card.dart';

extension _PostCardDialogs on _PostCardState {
  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.authorId == currentUserId) ...[
            if (widget.onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onEdit!();
                },
              ),
            if (widget.onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: AppTheme.errorColor),
                title: const Text('삭제',
                    style: TextStyle(color: AppTheme.errorColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context);
                },
              ),
          ] else ...[
            ListTile(
              leading: const Icon(
                Icons.report,
                color: AppTheme.warningColor,
              ),
              title: const Text('신고'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppTheme.errorColor),
              title: const Text('차단'),
              onTap: () {
                Navigator.pop(ctx);
                _showBlockDialog(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final accepted = await SocialContentReportSheet.show(
      context,
      target: SocialReportTarget.post,
      targetId: post.id,
      currentUserId: currentUserId,
      repository: socialRepository,
    );
    if (!accepted || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('신고가 접수되었습니다.'),
        ),
      );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${post.authorName}님을 차단할까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('서로의 콘텐츠와 활동이 제한됩니다.'),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.subtleBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
              ),
              child: Text(
                '서로의 게시물·댓글·프로필이 노출되지 않습니다.\n'
                '팔로우·좋아요·답글·신규 채팅 등 상호작용이 제한됩니다.\n'
                '기존 직접 채팅도 더 이상 사용할 수 없습니다.',
                style:
                    TextStyle(fontSize: AppTheme.fontCaption.sp, height: 1.5),
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              '개인정보 보호 설정에서 언제든 해제할 수 있어요.',
              style: TextStyle(
                fontSize: AppTheme.fontCaption.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final blockSvc = sl<BlockService>();
              final success = await blockSvc.blockUser(post.authorId);
              if (!context.mounted) return;
              if (success) {
                widget.onBlocked?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${post.authorName}님을 차단했습니다.'),
                    backgroundColor: AppTheme.errorColor,
                    action: SnackBarAction(
                      label: '차단 해제',
                      textColor: Colors.white,
                      onPressed: () async {
                        final ok = await blockSvc.unblockUser(post.authorId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? '${post.authorName}님의 차단이 해제되었습니다.'
                                : '차단 해제에 실패했습니다.'),
                          ),
                        );
                      },
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('차단 처리에 실패했습니다.')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('차단'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('정말로 이 게시물을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete!();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
