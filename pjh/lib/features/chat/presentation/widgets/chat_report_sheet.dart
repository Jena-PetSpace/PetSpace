import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

/// 채팅 신고 사유 선택 다이얼로그. social의 신고 사유 리스트·패턴을 동일하게
/// 복제한다(social 파일은 수정하지 않음). 선택한 사유 문자열을 반환하고,
/// 취소 시 null을 반환한다.
///
/// 실제 신고 저장(ReportChatTarget)·완료 안내는 호출부가 담당한다.
Future<String?> showChatReportSheet(
  BuildContext context, {
  required String title,
}) {
  String? selectedReason;
  const reasons = [
    '스팸 또는 광고',
    '폭력적이거나 위험한 콘텐츠',
    '허위 정보',
    '혐오 발언 또는 차별',
    '개인정보 침해',
    '기타',
  ];

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '신고 사유를 선택해주세요',
              style: TextStyle(
                fontSize: 14.sp,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
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
                ? () => Navigator.pop(ctx, selectedReason)
                : null,
            child: const Text('신고'),
          ),
        ],
      ),
    ),
  );
}
