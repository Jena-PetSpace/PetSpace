import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/entities/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSenderInfo;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSenderInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system) {
      return _buildSystemMessage(context);
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            if (showSenderInfo)
              CircleAvatar(
                radius: 16.r,
                backgroundColor: Colors.grey[200],
                backgroundImage: message.senderPhotoUrl != null
                    ? NetworkImage(message.senderPhotoUrl!)
                    : null,
                child: message.senderPhotoUrl == null
                    ? Icon(Icons.person, size: 16.w, color: Colors.grey[500])
                    : null,
              )
            else
              SizedBox(width: 32.w),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSenderInfo && !isMine)
                  Padding(
                    padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
                    child: Text(
                      message.senderName ?? '',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
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
                        child: Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                        ),
                      ),
                    Flexible(child: _buildMessageContent(context)),
                    if (!isMine)
                      Padding(
                        padding: EdgeInsets.only(left: 4.w, bottom: 2.h),
                        child: Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                        ),
                      ),
                  ],
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
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          '삭제된 메시지입니다',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (message.type == ChatMessageType.image && message.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: CachedNetworkImage(
          imageUrl: message.imageUrl!,
          width: 200.w,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 200.w,
            height: 150.h,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            width: 200.w,
            height: 150.h,
            color: Colors.grey[200],
            child: Icon(Icons.broken_image, size: 40.w, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isMine
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[200],
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
          color: isMine ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    if (hour < 12) {
      return '오전 ${hour == 0 ? 12 : hour}:$minute';
    } else {
      return '오후 ${hour == 12 ? 12 : hour - 12}:$minute';
    }
  }
}
