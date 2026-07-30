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
              title: const Text('게시물 신고'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('사용자 신고 · 차단'),
              onTap: () {
                Navigator.pop(ctx);
                _showUserActions(context);
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

  Future<void> _showUserActions(BuildContext context) async {
    await SocialUserActionsSheet.show(
      context,
      targetUserId: post.authorId,
      targetUserName: post.authorName,
      currentUserId: currentUserId,
      repository: socialRepository,
      onBlocked: widget.onBlocked,
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
