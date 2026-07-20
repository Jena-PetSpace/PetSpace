import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/widgets/image_viewer_page.dart';
import '../../domain/entities/chat_message.dart';
import '../../../../shared/themes/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSenderInfo;
  final int unreadCount;
  final bool showReadLabel;

  /// 상대 메시지 롱프레스 시 호출(메시지 신고 진입). 내 메시지/그룹 시스템엔 없음.
  final VoidCallback? onLongPress;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSenderInfo = false,
    this.unreadCount = 0,
    this.showReadLabel = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system) {
      return _buildSystemMessage(context);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            if (showSenderInfo)
              CircleAvatar(
                radius: 16.r,
                backgroundColor: AppTheme.actionContainer,
                backgroundImage: message.senderPhotoUrl != null
                    ? NetworkImage(message.senderPhotoUrl!)
                    : null,
                child: message.senderPhotoUrl == null
                    ? Icon(
                        Icons.person,
                        size: 16.w,
                        color: AppTheme.actionBase,
                      )
                    : null,
              )
            else
              SizedBox(width: 32.w),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSenderInfo && !isMine)
                  Padding(
                    padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
                    child: Text(
                      message.senderName ?? '',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isMine)
                      Padding(
                        padding: EdgeInsets.only(right: 4.w, bottom: 2.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (unreadCount > 0)
                              Padding(
                                padding: EdgeInsets.only(bottom: 2.h),
                                child: Text(
                                  '$unreadCount',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppTheme
                                        .warningColor, // v2-review: FF6B00 근사
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                  fontSize: 10.sp, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    Flexible(
                      child: (!isMine && onLongPress != null)
                          ? GestureDetector(
                              onLongPress: onLongPress,
                              child: _buildMessageContent(context),
                            )
                          : _buildMessageContent(context),
                    ),
                    if (!isMine)
                      Padding(
                        padding: EdgeInsets.only(left: 4.w, bottom: 2.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (unreadCount > 0)
                              Padding(
                                padding: EdgeInsets.only(bottom: 2.h),
                                child: Text(
                                  '$unreadCount',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: AppTheme
                                        .warningColor, // v2-review: FF6B00 근사
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                fontSize: AppTheme.fontMicro.sp,
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (showReadLabel && isMine)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h, right: 4.w),
                    child: Text(
                      '읽음',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMine) SizedBox(width: 8.w),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (message.isDeleted) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppTheme.actionContainer,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          '삭제된 메시지입니다',
          style: TextStyle(
            fontSize: 14.sp,
            color: AppTheme.secondaryTextColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // 멀티 이미지 메시지
    if (message.type == ChatMessageType.image &&
        message.imageUrls != null &&
        message.imageUrls!.length > 1) {
      return _buildMultiImageGrid(context, message.imageUrls!);
    }

    // 단일 이미지 메시지
    if (message.type == ChatMessageType.image && message.imageUrl != null) {
      final imageWidth = math.min(
        200.w,
        MediaQuery.sizeOf(context).width * 0.56,
      );
      return GestureDetector(
        onTap: () => _openImageViewer(context, [message.imageUrl!], 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: CachedNetworkImage(
            imageUrl: message.imageUrl!,
            width: imageWidth,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: imageWidth,
              height: imageWidth * 0.75,
              color: AppTheme.actionContainer,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              width: imageWidth,
              height: imageWidth * 0.75,
              color: AppTheme.actionContainer,
              child: Icon(
                Icons.broken_image,
                size: 40.w,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: Key(isMine ? 'chat_text_bubble_mine' : 'chat_text_bubble_other'),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isMine
            ? AppTheme.actionBase
            : Theme.of(context).colorScheme.surface,
        border: isMine ? null : Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
          bottomLeft: isMine ? Radius.circular(16.r) : Radius.circular(4.r),
          bottomRight: isMine ? Radius.circular(4.r) : Radius.circular(16.r),
        ),
      ),
      child: Text(
        message.content ?? '',
        style: TextStyle(
          fontSize: 14.sp,
          color:
              isMine ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  /// 카카오톡 스타일 멀티 이미지 그리드
  Widget _buildMultiImageGrid(BuildContext context, List<String> urls) {
    final gridWidth = math.min(
      250.w,
      MediaQuery.sizeOf(context).width * 0.56,
    );
    final spacing = 2.w;

    return ClipRRect(
      key: const Key('chat_multi_image_grid'),
      borderRadius: BorderRadius.circular(12.r),
      child: SizedBox(
        width: gridWidth,
        child: _buildGridLayout(context, urls, gridWidth, spacing),
      ),
    );
  }

  Widget _buildGridLayout(
    BuildContext context,
    List<String> urls,
    double gridWidth,
    double spacing,
  ) {
    final count = urls.length;

    if (count == 2) {
      // 2장: 가로 나란히
      final itemWidth = (gridWidth - spacing) / 2;
      return SizedBox(
        height: itemWidth,
        child: Row(
          children: [
            _buildGridImage(context, urls, 0, itemWidth, itemWidth),
            SizedBox(width: spacing),
            _buildGridImage(context, urls, 1, itemWidth, itemWidth),
          ],
        ),
      );
    }

    if (count == 3) {
      // 3장: 상단 1장 전체폭, 하단 2장 나란히
      final halfWidth = (gridWidth - spacing) / 2;
      final topHeight = gridWidth * 0.55;
      final bottomHeight = gridWidth * 0.45 - spacing;
      return Column(
        children: [
          _buildGridImage(context, urls, 0, gridWidth, topHeight),
          SizedBox(height: spacing),
          SizedBox(
            height: bottomHeight,
            child: Row(
              children: [
                _buildGridImage(context, urls, 1, halfWidth, bottomHeight),
                SizedBox(width: spacing),
                _buildGridImage(context, urls, 2, halfWidth, bottomHeight),
              ],
            ),
          ),
        ],
      );
    }

    if (count == 4) {
      // 4장: 2x2 그리드
      final itemSize = (gridWidth - spacing) / 2;
      return Column(
        children: [
          SizedBox(
            height: itemSize,
            child: Row(
              children: [
                _buildGridImage(context, urls, 0, itemSize, itemSize),
                SizedBox(width: spacing),
                _buildGridImage(context, urls, 1, itemSize, itemSize),
              ],
            ),
          ),
          SizedBox(height: spacing),
          SizedBox(
            height: itemSize,
            child: Row(
              children: [
                _buildGridImage(context, urls, 2, itemSize, itemSize),
                SizedBox(width: spacing),
                _buildGridImage(context, urls, 3, itemSize, itemSize),
              ],
            ),
          ),
        ],
      );
    }

    // 5장 이상: 2x2 그리드 + 마지막 칸에 "+N" 오버레이
    final itemSize = (gridWidth - spacing) / 2;
    final remaining = count - 4;
    return Column(
      children: [
        SizedBox(
          height: itemSize,
          child: Row(
            children: [
              _buildGridImage(context, urls, 0, itemSize, itemSize),
              SizedBox(width: spacing),
              _buildGridImage(context, urls, 1, itemSize, itemSize),
            ],
          ),
        ),
        SizedBox(height: spacing),
        SizedBox(
          height: itemSize,
          child: Row(
            children: [
              _buildGridImage(context, urls, 2, itemSize, itemSize),
              SizedBox(width: spacing),
              // 마지막 칸: 4번째 이미지 + "+N" 오버레이
              GestureDetector(
                onTap: () => _openImageViewer(context, urls, 3),
                child: SizedBox(
                  width: itemSize,
                  height: itemSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: urls[3],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppTheme.actionContainer,
                          child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppTheme.actionContainer,
                          child: Icon(Icons.broken_image,
                              size: 24.w, color: AppTheme.secondaryTextColor),
                        ),
                      ),
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: Center(
                          child: Text(
                            '+$remaining',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridImage(
    BuildContext context,
    List<String> allUrls,
    int index,
    double width,
    double height,
  ) {
    return GestureDetector(
      onTap: () => _openImageViewer(context, allUrls, index),
      child: SizedBox(
        width: width,
        height: height,
        child: CachedNetworkImage(
          imageUrl: allUrls[index],
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppTheme.actionContainer,
            child:
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppTheme.actionContainer,
            child: Icon(
              Icons.broken_image,
              size: 24.w,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }

  void _openImageViewer(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('chat_system_message'),
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppTheme.actionContainer,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 12.sp,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    if (hour < 12) {
      return '오전 ${hour == 0 ? 12 : hour}:$minute';
    } else {
      return '오후 ${hour == 12 ? 12 : hour - 12}:$minute';
    }
  }
}
