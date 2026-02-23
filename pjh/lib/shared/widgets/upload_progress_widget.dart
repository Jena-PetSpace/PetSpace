import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

class UploadProgressWidget extends StatelessWidget {
  final double progress;
  final String fileName;
  final bool isCompleted;
  final String? error;
  final VoidCallback? onCancel;

  const UploadProgressWidget({
    super.key,
    required this.progress,
    required this.fileName,
    this.isCompleted = false,
    this.error,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIcon(),
                color: _getIconColor(),
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCancel != null && !isCompleted && error == null)
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(Icons.close, size: 18.w),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 24.w,
                    minHeight: 24.w,
                  ),
                ),
            ],
          ),
          if (!isCompleted && error == null) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            SizedBox(height: 4.h),
            Text(
              error!,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.red,
              ),
            ),
          ],
          if (isCompleted && error == null) ...[
            SizedBox(height: 4.h),
            Text(
              '업로드 완료',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIcon() {
    if (error != null) return Icons.error_outline;
    if (isCompleted) return Icons.check_circle_outline;
    return Icons.cloud_upload_outlined;
  }

  Color _getIconColor() {
    if (error != null) return Colors.red;
    if (isCompleted) return Colors.green;
    return AppTheme.primaryColor;
  }

  Color _getBorderColor() {
    if (error != null) return Colors.red.withValues(alpha: 0.3);
    if (isCompleted) return Colors.green.withValues(alpha: 0.3);
    return AppTheme.primaryColor.withValues(alpha: 0.3);
  }
}

class MultipleUploadProgressWidget extends StatelessWidget {
  final List<UploadProgress> uploads;

  const MultipleUploadProgressWidget({
    super.key,
    required this.uploads,
  });

  @override
  Widget build(BuildContext context) {
    if (uploads.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_upload,
                  color: AppTheme.primaryColor,
                  size: 24.w,
                ),
                SizedBox(width: 8.w),
                Text(
                  '이미지 업로드 중',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.w),
            itemCount: uploads.length,
            separatorBuilder: (context, index) => SizedBox(height: 8.h),
            itemBuilder: (context, index) {
              final upload = uploads[index];
              return UploadProgressWidget(
                progress: upload.progress,
                fileName: upload.fileName,
                isCompleted: upload.isCompleted,
                error: upload.error,
                onCancel: upload.onCancel,
              );
            },
          ),
        ],
      ),
    );
  }
}

class UploadProgress {
  final double progress;
  final String fileName;
  final bool isCompleted;
  final String? error;
  final VoidCallback? onCancel;

  UploadProgress({
    required this.progress,
    required this.fileName,
    this.isCompleted = false,
    this.error,
    this.onCancel,
  });

  UploadProgress copyWith({
    double? progress,
    String? fileName,
    bool? isCompleted,
    String? error,
    VoidCallback? onCancel,
  }) {
    return UploadProgress(
      progress: progress ?? this.progress,
      fileName: fileName ?? this.fileName,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
      onCancel: onCancel ?? this.onCancel,
    );
  }
}
