import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/repositories/social_repository.dart';

enum SocialReportTarget { post, comment, user }

class SocialContentReportSheet extends StatefulWidget {
  static const List<String> reasons = <String>[
    '스팸 또는 광고',
    '폭력적이거나 위험한 콘텐츠',
    '허위 정보',
    '혐오 발언 또는 차별',
    '개인정보 침해',
    '기타',
  ];

  final SocialReportTarget target;
  final String targetId;
  final String currentUserId;
  final SocialRepository repository;

  const SocialContentReportSheet({
    super.key,
    required this.target,
    required this.targetId,
    required this.currentUserId,
    required this.repository,
  });

  static Future<bool> show(
    BuildContext context, {
    required SocialReportTarget target,
    required String targetId,
    required String currentUserId,
    required SocialRepository repository,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SocialContentReportSheet(
        target: target,
        targetId: targetId,
        currentUserId: currentUserId,
        repository: repository,
      ),
    );
    return result ?? false;
  }

  @override
  State<SocialContentReportSheet> createState() =>
      _SocialContentReportSheetState();
}

class _SocialContentReportSheetState extends State<SocialContentReportSheet> {
  String? _selectedReason;
  bool _isSubmitting = false;
  String? _errorMessage;

  String get _targetLabel => switch (widget.target) {
        SocialReportTarget.post => '게시물',
        SocialReportTarget.comment => '댓글',
        SocialReportTarget.user => '사용자',
      };

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null ||
        widget.currentUserId.isEmpty ||
        widget.targetId.isEmpty ||
        _isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await switch (widget.target) {
      SocialReportTarget.post => widget.repository.reportPost(
          widget.targetId,
          widget.currentUserId,
          reason,
        ),
      SocialReportTarget.comment => widget.repository.reportComment(
          widget.targetId,
          widget.currentUserId,
          reason,
        ),
      SocialReportTarget.user => widget.repository.reportUser(
          widget.targetId,
          widget.currentUserId,
          reason,
        ),
    };
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _isSubmitting = false;
        _errorMessage = '신고를 접수하지 못했어요. 잠시 후 다시 시도해주세요.';
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    const SizedBox(width: 44, height: 44),
                    Expanded(
                      child: Text(
                        '$_targetLabel 신고',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        key: const Key('social_report_close'),
                        onPressed:
                            _isSubmitting ? null : () => Navigator.pop(context),
                        tooltip: '신고 닫기',
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
                Text(
                  '신고 사유를 선택해주세요. 접수 후 운영 정책에 따라 검토합니다.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                SizedBox(height: 8.h),
                ...SocialContentReportSheet.reasons.map(
                  (reason) => RadioListTile<String>(
                    key: Key('social_report_reason_$reason'),
                    value: reason,
                    // ignore: deprecated_member_use
                    groupValue: _selectedReason,
                    // ignore: deprecated_member_use
                    onChanged: _isSubmitting
                        ? null
                        : (value) => setState(() {
                              _selectedReason = value;
                              _errorMessage = null;
                            }),
                    title: Text(reason, style: TextStyle(fontSize: 14.sp)),
                    activeColor: AppTheme.primaryColor,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    _errorMessage!,
                    key: const Key('social_report_error'),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: FilledButton(
                    key: const Key('social_report_submit'),
                    onPressed: _selectedReason == null || _isSubmitting
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.actionBase,
                      foregroundColor: AppTheme.surfaceColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.surfaceColor,
                            ),
                          )
                        : const Text('신고 접수', textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
