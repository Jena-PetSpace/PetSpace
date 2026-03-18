import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/social_user.dart';
import '../../domain/repositories/social_repository.dart';

class LikesBottomSheet extends StatefulWidget {
  final String postId;
  final String? currentUserId;

  const LikesBottomSheet({
    super.key,
    required this.postId,
    this.currentUserId,
  });

  static void show(BuildContext context,
      {required String postId, String? currentUserId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          LikesBottomSheet(postId: postId, currentUserId: currentUserId),
    );
  }

  @override
  State<LikesBottomSheet> createState() => _LikesBottomSheetState();
}

class _LikesBottomSheetState extends State<LikesBottomSheet> {
  List<SocialUser>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLikes();
  }

  Future<void> _loadLikes() async {
    final result = await di.sl<SocialRepository>().getPostLikes(widget.postId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _error = failure.message),
      (users) => setState(() => _users = users),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Text(
              '좋아요',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            const Divider(height: 1),
            Expanded(child: _buildContent(scrollController)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_error != null) {
      return Center(
        child: Text('오류: $_error',
            style: TextStyle(fontSize: 14.sp, color: Colors.red)),
      );
    }

    if (_users == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users!.isEmpty) {
      return Center(
        child: Text('아직 좋아요가 없습니다',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _users!.length,
      itemBuilder: (context, index) {
        final user = _users![index];
        return ListTile(
          leading: CircleAvatar(
            radius: 20.r,
            backgroundImage: user.profileImageUrl != null
                ? CachedNetworkImageProvider(user.profileImageUrl!)
                : null,
            child: user.profileImageUrl == null
                ? Text(
                    user.displayName.isNotEmpty ? user.displayName[0] : '?',
                    style: TextStyle(fontSize: 14.sp),
                  )
                : null,
          ),
          title: Text(user.displayName,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
          subtitle: user.username != null
              ? Text('@${user.username}',
                  style: TextStyle(
                      fontSize: 12.sp, color: AppTheme.secondaryTextColor))
              : null,
          onTap: () {
            Navigator.pop(context);
            context.push(
                '/user-profile/${user.id}?currentUserId=${widget.currentUserId ?? ''}');
          },
        );
      },
    );
  }
}
