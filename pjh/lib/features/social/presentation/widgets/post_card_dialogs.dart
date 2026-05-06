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
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context);
                },
              ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('신고'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
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

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    final reasons = [
      '스팸 또는 광고',
      '폭력적이거나 위험한 콘텐츠',
      '허위 정보',
      '혐오 발언 또는 차별',
      '개인정보 침해',
      '기타',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('게시물 신고'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '신고 사유를 선택해주세요',
                style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              SizedBox(height: 12.h),
              ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason, style: TextStyle(fontSize: 14.sp)),
                    value: reason,
                    // ignore: deprecated_member_use
                    groupValue: selectedReason,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setDialogState(() => selectedReason = value);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppTheme.primaryColor,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: selectedReason != null
                  ? () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  : null,
              child: const Text('신고'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사용자 차단'),
        content: Text(
          '${post.authorName}님을 차단하시겠습니까?\n\n차단하면 해당 사용자의 게시물과 댓글이 보이지 않습니다.',
          style: TextStyle(fontSize: 14.sp),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${post.authorName}님을 차단했습니다.'),
                    backgroundColor: Colors.red,
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
